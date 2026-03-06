# Conversation Capture — Execution Plan

> Derived from [PRD](./prd-granola.md). Milestones 0–8 = MVP (Phase 1), 9–12 = P1 (Phase 2), 13–14 = P2 (Phase 3), 15–18 = Relationship Intelligence (Phase 4).

---

## [ ] Milestone 0: Audio Quality Spike (1 week)

> **Goal:** Validate that HFP Bluetooth audio from Meta glasses produces usable transcriptions before committing to full build.

- [ ] Record 10 test conversations (5–30 min) via glasses HFP mic using existing `AudioManager.startRecording()`
- [ ] Record same conversations simultaneously via device built-in mic for comparison
- [ ] Transcribe both audio sources with Whisper API (`POST /v1/audio/transcriptions`, model `whisper-1`)
- [ ] Calculate Word Error Rate (WER) for each: target <15% in quiet, <25% in noisy
- [ ] Test in varied environments: quiet office, coffee shop, outdoor walk, conference room
- [ ] Test with multiple speakers at different distances from glasses wearer
- [ ] Document findings and go/no-go decision in `docs/spike-audio-quality.md`

---

## [x] Milestone 1: Data Models & Persistence (Week 1)

> **Goal:** Define all data structures and file storage for captures. New file: `CaptureModels.swift`.

- [x] Create `CaptureModels.swift` with core types:
  - [x] `CaptureSession` struct (id, createdAt, updatedAt, title, duration, audioFilePath, transcriptStatus, summaryStatus, audioSource, wordCount, location)
  - [x] `TranscriptStatus` enum (pending, inProgress, completed, failed)
  - [x] `SummaryStatus` enum (pending, inProgress, completed, failed)
  - [x] `AudioSource` enum (glasses, deviceMic)
  - [x] `CaptureState` enum (idle, recording, processing, completed, error)
  - [x] `Transcript` struct (captureId, segments, fullText, language, provider)
  - [x] `TranscriptSegment` struct (startTime, endTime, text, speaker, confidence)
  - [x] `CaptureSummary` struct (captureId, keyPoints, decisions, actionItems, topics, sentiment)
  - [x] `ActionItem` struct (description, assignee, deadline, isCompleted)
- [x] All types conform to `Identifiable`, `Codable`, `Equatable`
- [x] Create `Documents/captures/` directory structure on first use
- [x] Implement `CaptureStore` for JSON persistence of `captures_index.json`
  - [x] `func save(_ session: CaptureSession)`
  - [x] `func loadAll() -> [CaptureSession]`
  - [x] `func delete(id: UUID)` — removes session + audio/transcript/summary files
  - [x] `func saveTranscript(_ transcript: Transcript, for captureId: UUID)`
  - [x] `func loadTranscript(for captureId: UUID) -> Transcript?`
  - [x] `func saveSummary(_ summary: CaptureSummary, for captureId: UUID)`
  - [x] `func loadSummary(for captureId: UUID) -> CaptureSummary?`
- [x] Use ISO8601 date encoding, atomic writes (match `ThreadsManager` pattern)

---

## [x] Milestone 2: ConversationCaptureManager (Week 1–2)

> **Goal:** Core manager singleton that orchestrates capture lifecycle. New file: `ConversationCaptureManager.swift`.

- [x] Create `ConversationCaptureManager` class
  - [x] `@MainActor` isolation, `ObservableObject`, `static let shared` singleton pattern
- [x] Implement state machine:
  - [x] `@Published captureState: CaptureState` — idle → recording → processing → completed
  - [x] `@Published elapsedTime: TimeInterval` — timer updated every second
  - [x] `@Published audioLevel: Float` — mic level 0.0–1.0
  - [x] `@Published audioSource: AudioSource` — "Meta Glasses" or "Device Microphone"
  - [x] `@Published currentSession: CaptureSession?` — active capture metadata
- [x] `func startCapture()`:
  - [x] Check mic permission via `PermissionsManager`
  - [x] Configure HFP audio via own `AudioManager` instance
  - [x] Detect audio source (glasses Bluetooth vs device mic)
  - [x] Create `CaptureSession` with metadata + location from `LocationManager`
  - [x] Create capture directory `Documents/captures/[uuid]/`
  - [x] Call `AudioManager.startRecording()` → save to `captures/[uuid]/audio.m4a`
  - [x] Start elapsed time timer (`Timer.publish`)
  - [x] Set `UIApplication.shared.isIdleTimerDisabled = true`
  - [x] Play start sound via `SoundManager.shared`
- [x] `func stopCapture()`:
  - [x] Call `AudioManager.stopRecording()` → get audio file URL
  - [x] Update `CaptureSession` with duration
  - [x] Set `UIApplication.shared.isIdleTimerDisabled = false`
  - [x] Play stop sound via `SoundManager.shared`
  - [x] Transition to `.processing` state
  - [x] Trigger transcription pipeline (Milestone 3)
- [x] `func cancelCapture()`:
  - [x] Call `AudioManager.cancelRecording()`
  - [x] Delete capture directory
  - [x] Reset to `.idle`
- [x] Handle Bluetooth disconnection mid-capture:
  - [x] Observe audio route changes
  - [x] Update `audioSource` if fallback to device mic
  - [ ] Show alert but continue recording

---

## [x] Milestone 3: Whisper API Transcription Pipeline (Week 3)

> **Goal:** Send recorded audio to Whisper API and receive timestamped transcript. New file: `WhisperAPIClient.swift`.

- [x] Add Whisper API URL to `Constants.swift`:
  - [x] `static let whisperTranscriptionURL = "https://api.openai.com/v1/audio/transcriptions"`
- [x] Create `WhisperAPIClient.swift`:
  - [x] `@MainActor` class, uses OpenAI API key from `SettingsManager`
  - [x] `func transcribe(audioFileURL: URL) async throws -> Transcript`
  - [x] Build `multipart/form-data` request:
    - [x] File field: M4A audio data
    - [x] Model: `whisper-1` (from `Constants.whisperModel`)
    - [x] Response format: `verbose_json` (includes segment timestamps)
    - [x] Language: auto-detect
  - [x] Parse response into `Transcript` model with segments
  - [x] Handle file size limit (25MB): chunk audio for sessions >90 min
- [x] Log API calls via `APIDebugLogger`
- [x] Integrate into `ConversationCaptureManager.stopCapture()` flow:
  - [x] Call `WhisperAPIClient.transcribe()` after recording stops
  - [x] Update `CaptureSession.transcriptStatus` as pipeline progresses
  - [x] Save transcript via `CaptureStore.saveTranscript()`
  - [x] On failure: set status to `.failed`, allow retry
- [x] Handle network errors gracefully:
  - [x] Save audio file regardless of transcription success
  - [x] Allow manual retry from capture detail view
  - [x] Timeout: 120 seconds for upload + processing

---

## [x] Milestone 4: AI Summary Generation (Week 4)

> **Goal:** Generate structured summary from transcript using GPT-4o-mini.

- [x] Add summary generation to `ConversationCaptureManager`:
  - [x] `private func generateSummary(transcript: Transcript) async throws -> CaptureSummary`
  - [x] Use `Constants.openAIChatCompletionsURL` with `Constants.fastModel`
  - [x] Build prompt from PRD Section 10.4 (key points, decisions, action items, topics)
  - [x] Parse structured JSON response into `CaptureSummary`
  - [x] Save via `CaptureStore.saveSummary()`
  - [x] Update `CaptureSession.summaryStatus`
- [x] Auto-generate capture title from transcript:
  - [x] Reuse pattern from `ThreadsManager.generateAndUpdateThreadTitle()`
  - [x] 4-word descriptive title via GPT-4o-mini, max 30 tokens
  - [x] Update `CaptureSession.title`
- [x] Chain after transcription:
  - [x] `stopCapture()` → transcribe → summarize → set state to `.completed`
  - [x] Each step updates `CaptureSession` status fields for UI progress
- [x] Handle partial failures:
  - [x] Transcript succeeds but summary fails → still show transcript, allow summary retry
  - [x] Both fail → show error, keep audio, allow full retry

---

## [x] Milestone 5: Capture UI — ConversationCaptureView (Week 2–3)

> **Goal:** New SwiftUI view for the Capture tab. New file: `ConversationCaptureView.swift`.

- [x] Add Capture tab to `ContentView.swift`:
  - [x] Add `case capture` to `AppTab` enum (between `threads` and `settings`)
  - [x] Add TabView item with `LazyView(ConversationCaptureView())` pattern
  - [x] Tab icon: `waveform` SF Symbol
- [x] Create `ConversationCaptureView.swift`:
  - [x] `@ObservedObject var captureManager = ConversationCaptureManager.shared`
  - [x] `@ObservedObject var settingsManager = SettingsManager.shared`
- [x] **Idle state UI:**
  - [x] Audio source indicator (glasses connected / device mic)
  - [x] Large "Start Capture" button
  - [x] Recent captures list (last 5) with title, date, duration
  - [x] First-time consent disclaimer (check `SettingsManager` flag)
- [x] **Recording state UI:**
  - [x] Pulsing red record indicator
  - [x] Elapsed time display (MM:SS format)
  - [x] Audio level visualization
  - [x] Audio source label ("Meta Glasses" / "Device Microphone")
  - [x] Large "Stop" button
  - [x] "Cancel" option (with confirmation alert)
- [x] **Processing state UI:**
  - [x] "Transcribing..." progress indicator
  - [x] Show transcription status, then summary status
- [x] **Completed state UI:**
  - [x] Show inline summary preview with "View Details" / "New Capture" buttons
- [x] **Error state UI:**
  - [x] Error message display
  - [x] "Retry" button (re-trigger transcription/summary)
  - [x] "Dismiss" to return to idle
- [x] Permission gating:
  - [x] Check microphone permission (follow `VoiceAgentView` pattern)
  - [x] Check OpenAI API key configured
  - [x] Show appropriate permission/setup views if missing

---

## [x] Milestone 6: Thread & Settings Integration (Week 4)

> **Goal:** Captures appear in Threads, capture settings in Settings tab.

- [x] Extend `ConversationThread` in `ThreadsManager.swift`:
  - [x] Add `var threadType: ThreadType` field (default `.voiceAgent` for migration)
  - [x] Add `var captureId: UUID?` field (optional, for capture threads)
  - [x] Add `ThreadType` enum: `.voiceAgent`, `.capture`
  - [x] Update `init(from decoder:)` with migration fallbacks for new fields
- [x] Update `ThreadsView` to handle capture threads:
  - [x] Show different icon for capture threads vs voice agent threads
  - [x] Tap on capture thread → navigate to `CaptureDetailView` (not voice agent)
- [x] Extend `AppSettings` in `SettingsManager.swift`:
  - [x] Add `var captureAutoSummary: Bool` (default `true`)
  - [x] Add `var captureConsentAcknowledged: Bool` (default `false`)
  - [x] Update `init(from decoder:)` with `decodeIfPresent` fallbacks
- [x] Add Capture section to `SettingsView.swift`:
  - [x] Toggle: "Auto-generate summary after transcription"
  - [x] Privacy disclaimer text
  - [x] Reset consent acknowledgment option

---

## [x] Milestone 7: Capture Detail View (Week 4–5)

> **Goal:** View for reviewing past captures. New file: `CaptureDetailView.swift`.

- [x] Create `CaptureDetailView.swift`:
  - [x] Input: `captureId: UUID` (loaded from store)
  - [x] Tab/segment selector: Summary | Transcript
- [x] **Summary tab:**
  - [x] Title (editable via toolbar)
  - [x] Date, duration, word count, audio source metadata
  - [x] Key Points section (bulleted list)
  - [x] Decisions section (bulleted list)
  - [x] Action Items section (checkbox list, toggleable `isCompleted`)
  - [x] Topics as tag pills (FlowLayout)
- [x] **Transcript tab:**
  - [x] Scrollable timestamped text
  - [x] Each segment: `[MM:SS] text`
- [x] **Actions:**
  - [x] Delete capture (confirmation alert, removes all files)
  - [x] Retry transcription (if failed)
  - [x] Retry summary (if failed)
- [x] Navigation from `ThreadsView`:
  - [x] Detect `threadType == .capture` → push `CaptureDetailView`
  - [x] Load `CaptureSession` + `Transcript` + `CaptureSummary` from `CaptureStore`
- [x] Navigation from `ConversationCaptureView`:
  - [x] After processing completes → navigate to `CaptureDetailView`

---

## [ ] Milestone 8: Polish, Error Handling & Testing (Week 5–6)

> **Goal:** Production-ready MVP with robust error handling and edge case coverage.

- [x] Add capture start/stop sounds to `SoundManager.swift`:
  - [x] `playCaptureStartSound()` — ascending three-tone (440, 660, 880 Hz)
  - [x] `playCaptureStopSound()` — descending two-tone (880, 440 Hz)
- [ ] Background audio support:
  - [ ] Verify `audio` background mode in Info.plist / Xcode capabilities
  - [ ] Test recording continues when app is backgrounded
  - [ ] Test recording survives phone lock (idle timer already disabled)
- [ ] Bluetooth disconnection handling:
  - [ ] Detect route change during recording
  - [ ] Auto-fallback to device mic with user notification
  - [ ] Continue recording without interruption
- [ ] Long recording handling:
  - [ ] Test 30-min, 60-min, 90-min recordings
  - [ ] Audio file chunking for Whisper API 25MB limit
  - [ ] Merge chunked transcripts with correct timestamps
- [ ] Storage management:
  - [ ] Show storage used by captures in Settings
  - [ ] Option to delete audio after successful transcription
- [ ] Edge cases:
  - [ ] Start capture with no network → record audio, queue transcription for later
  - [ ] App killed during recording → recover partial audio file on next launch
  - [ ] Multiple rapid start/stop → debounce, prevent state corruption
  - [ ] Low disk space → warn before starting capture
- [ ] API error handling:
  - [ ] Whisper API timeout/failure → keep audio, show retry
  - [ ] Summary API failure → show transcript without summary, show retry
  - [ ] Invalid API key → show settings redirect
- [ ] MVP exit criteria validation:
  - [ ] Record 30-min conversation via glasses mic successfully
  - [ ] Transcription accuracy >85% WER in quiet environment
  - [ ] Summary correctly identifies key points and action items
  - [ ] Capture appears in Threads tab and is browseable
  - [ ] Works with glasses disconnected (device mic fallback)
  - [ ] No crashes during extended recording sessions

---

## [ ] Milestone 9 (P1): Real-Time Transcription — Deepgram (Week 7–8)

> **Goal:** Live transcript during capture via Deepgram WebSocket streaming.

- [ ] Add Deepgram API key field to `AppSettings` and `SettingsView`
- [ ] Add Deepgram WebSocket URL to `Constants.swift`
- [ ] Create `DeepgramStreamClient.swift`:
  - [ ] WebSocket connection to `wss://api.deepgram.com/v1/listen`
  - [ ] Follow `RealtimeAPIClient` WebSocket patterns
  - [ ] Stream PCM16 audio chunks in real-time
  - [ ] Receive interim and final transcript events
  - [ ] Publish `@Published currentTranscript: String`
- [ ] Integrate with `ConversationCaptureManager`:
  - [ ] Dual pipeline: record to file (AudioManager) + stream to Deepgram
  - [ ] Audio tap on AVAudioEngine input node (same pattern as RealtimeAPIClient)
  - [ ] Convert to Deepgram-required format
- [ ] Update `ConversationCaptureView` recording state:
  - [ ] Show live scrolling transcript below timer
  - [ ] Auto-scroll to latest text
- [ ] Add transcription provider setting:
  - [ ] `TranscriptionProvider` enum in settings (whisperAPI, deepgram)
  - [ ] Provider picker in Settings → Capture section
- [ ] Fallback: if Deepgram fails mid-capture, still have audio file for Whisper batch

---

## [ ] Milestone 10 (P1): Inline Notes & AI Enhancement (Week 8–10)

> **Goal:** Users type rough notes during capture; AI enhances them with transcript context (Granola's core feature).

- [ ] Add inline notes to `ConversationCaptureManager`:
  - [ ] `@Published inlineNotes: String` — bound to text editor
  - [ ] Save raw notes to `captures/[uuid]/notes.txt` on stop
- [ ] Add `EnhancedNotes` model to `CaptureModels.swift`:
  - [ ] `rawNotes: String`, `enhancedContent: String` (markdown), `enhancedAt: Date`
- [ ] Add notes editor to `ConversationCaptureView` recording state:
  - [ ] Collapsible text editor below audio level / live transcript
  - [ ] Minimal UI — just a text field, no formatting toolbar
  - [ ] Keyboard dismiss on scroll
- [ ] Build AI note enhancement pipeline:
  - [ ] `func enhanceNotes(rawNotes: String, transcript: Transcript) async throws -> EnhancedNotes`
  - [ ] Prompt: merge user notes + full transcript → structured enhanced markdown
  - [ ] Use GPT-4o-mini via Chat Completions API
  - [ ] Run after transcription completes (in parallel with summary generation)
- [ ] Save enhanced notes to `captures/[uuid]/enhanced_notes.json`
- [ ] Add Notes tab to `CaptureDetailView`:
  - [ ] Show raw notes (editable) and enhanced notes (read-only markdown)
  - [ ] Option to re-enhance after editing raw notes
- [ ] If no notes taken: skip enhancement, show only summary + transcript

---

## [ ] Milestone 11 (P1): Chat with Transcript (Week 10–11)

> **Goal:** Ask questions about any past captured conversation.

- [ ] Add Chat tab to `CaptureDetailView`:
  - [ ] Simple chat UI: message list + text input (reuse `TextInputBar` pattern)
  - [ ] `@State chatMessages: [ChatMessage]`
- [ ] Build chat-with-transcript API call:
  - [ ] `func chatWithTranscript(question: String, transcript: Transcript, summary: CaptureSummary?) async throws -> String`
  - [ ] System prompt: "You are answering questions about a recorded conversation. Cite timestamps when relevant."
  - [ ] Include full transcript + summary as context
  - [ ] Use GPT-4o-mini via Chat Completions API
- [ ] Display AI response with timestamp citations as tappable links
- [ ] Persist chat history per capture (optional — start without persistence)
- [ ] Log API calls via `APIDebugLogger`

---

## [ ] Milestone 12 (P1): Speaker Labels, Consent & Photo Snapshots (Week 11–12)

> **Goal:** Polish features for production P1 release.

- [ ] **Speaker labeling:**
  - [ ] Add `SpeakerLabel` enum to `CaptureModels.swift` (user, other, unknown)
  - [ ] Heuristic: louder/closer audio = "You", quieter = "Other"
  - [ ] Apply labels post-transcription via audio level analysis or prompt-based labeling
  - [ ] Display speaker labels in transcript view with color coding
- [ ] **Consent prompt:**
  - [ ] Add `captureConsentPrompt: Bool` setting to `AppSettings`
  - [ ] When enabled: play verbal announcement through glasses speakers at capture start
  - [ ] "This conversation is being recorded for note-taking purposes"
  - [ ] Use `AVSpeechSynthesizer` or pre-recorded audio
  - [ ] Show consent card on phone screen that can be shown to participants
- [ ] **Photo snapshots during capture:**
  - [ ] Add "Snap" button to recording UI (only when glasses streaming)
  - [ ] Capture photo via `GlassesManager.capturePhoto()`
  - [ ] Save to `captures/[uuid]/photos/[timestamp].jpg`
  - [ ] Link photo to current transcript timestamp
  - [ ] Display photos inline in transcript view at their timestamps
- [ ] **Export (basic):**
  - [ ] Share button on `CaptureDetailView`
  - [ ] Export summary + action items as plain text via `UIActivityViewController`

---

## [ ] Milestone 13 (P2): Offline Transcription — WhisperKit (Future)

> **Goal:** On-device transcription with zero network dependency.

- [ ] Add WhisperKit Swift Package dependency
- [ ] Model download manager (first-use ~500MB download)
- [ ] Model storage in app's caches directory
- [ ] `WhisperKitClient.swift`:
  - [ ] `func transcribe(audioFileURL: URL) async throws -> Transcript`
  - [ ] On-device inference using Core ML / ANE
  - [ ] Match output format to `Transcript` model
- [ ] Add `whisperKit` option to `TranscriptionProvider` enum
- [ ] Settings UI for model download/management
- [ ] Auto-select offline mode when no network available
- [ ] Queue failed cloud transcriptions for offline retry

---

## [ ] Milestone 14 (P2): Search, Insights & Integrations (Future)

> **Goal:** Cross-conversation intelligence and external tool integration.

- [ ] **Full-text search:**
  - [ ] Build search index from `Transcript.fullText` across all captures
  - [ ] Search UI: search bar in Threads/Capture list
  - [ ] Highlight matching text in transcript view
- [ ] **Cross-conversation insights:**
  - [ ] "What topics came up most this week?"
  - [ ] "Summarize all conversations with [person]"
  - [ ] Topic frequency analysis across captures
- [ ] **Action item tracking:**
  - [ ] Aggregate action items across all captures
  - [ ] Dedicated action items view with completion tracking
  - [ ] Follow-up reminders (local notifications)
- [ ] **Calendar integration:**
  - [ ] Link captures to calendar events
  - [ ] Suggest auto-start at meeting time
  - [ ] Pre-fill capture title from calendar event
- [ ] **Export integrations:**
  - [ ] Export to Notion (API)
  - [ ] Export to email (formatted summary)
  - [ ] Export as PDF
- [ ] **Voice-triggered start:**
  - [ ] "Hey Meta, start capturing" via Siri intent
  - [ ] Extend existing `SiriIntents.swift` with capture shortcut

---

## [ ] Milestone 15 (P1): Person Profiles & Face Recognition

> **Goal:** Foundation for Relationship Intelligence — detect and recognize faces from glasses camera, create person profiles.

- [ ] Create `PersonProfile.swift` with data models:
  - [ ] `PersonProfile` struct (id, name, nameSource, faceEmbedding, referencePhotoPath, organization, role, personalFacts, captureIds, relationshipType, lastSeenAt, conversationCount)
  - [ ] `PersonalFact` struct (fact, captureId, category)
  - [ ] `FactCategory` enum (family, work, interests, plans, preferences)
  - [ ] `Commitment` struct (description, direction, status, deadline, personId, captureId)
  - [ ] `CommitmentDirection` enum (youToThem, themToYou, mutual)
  - [ ] `CommitmentStatus` enum (pending, completed, overdue, cancelled)
  - [ ] `RelationshipBriefing` struct (personId, smallTalkSuggestions, pendingCommitments, keyTopics, conversationHistory)
- [ ] Create `PersonStore.swift` for JSON persistence:
  - [ ] `Documents/people/people_index.json` for all profiles
  - [ ] `Documents/people/[uuid]/` per-person directory
  - [ ] CRUD operations for PersonProfile, Commitment
- [ ] Create `FaceRecognitionEngine.swift`:
  - [ ] Apple Vision `VNDetectFaceRectanglesRequest` for face detection in photos
  - [ ] Crop and normalize detected face region
  - [ ] Core ML model integration (MobileFaceNet or ArcFace, ~10MB)
  - [ ] Generate 128-dim face embedding vector from cropped face
  - [ ] Cosine similarity matching against stored embeddings
  - [ ] Match threshold tuning (0.6-0.7 similarity)
- [ ] Create `PersonManager.swift` singleton:
  - [ ] `@MainActor`, `ObservableObject`, `static let shared`
  - [ ] `func identifyPerson(from photo: Data) async -> PersonProfile?`
  - [ ] `func createProfile(from photo: Data, captureId: UUID) -> PersonProfile`
  - [ ] `func linkCapture(captureId: UUID, to personId: UUID)`
- [ ] Add "Snap Person" to capture flow:
  - [ ] Button in `ConversationCaptureView` recording UI
  - [ ] Calls `GlassesManager.capturePhotoAsync()` to take photo
  - [ ] Runs face detection + embedding + matching pipeline
  - [ ] If known person: show name; if new: create profile
- [ ] Add `personIds: [UUID]` to `CaptureSession` model
- [ ] Privacy: Add Relationship Intelligence opt-in toggle to Settings
  - [ ] OFF by default
  - [ ] Clear explanation of on-device face processing
  - [ ] Consent dialog before first use

---

## [ ] Milestone 16 (P1): Relationship Intelligence Extraction

> **Goal:** AI extracts personal facts and commitments from transcripts; generates briefings when meeting known people.

- [ ] Extend post-capture AI pipeline in `ConversationCaptureManager`:
  - [ ] After summary generation, run relationship extraction prompt
  - [ ] Extract: person name, personal facts, commitments from transcript
  - [ ] Link extracted data to PersonProfile (matched by face or name)
- [ ] Relationship extraction prompt:
  - [ ] Identify people mentioned in conversation
  - [ ] Extract personal facts (family, hobbies, plans, work details)
  - [ ] Extract commitments with direction (you→them, them→you, mutual)
  - [ ] Return structured JSON for parsing
- [ ] Name extraction and matching:
  - [ ] If person introduced themselves: extract name from transcript
  - [ ] Match to existing profile by face embedding OR name similarity
  - [ ] If no match: create new profile, prompt user to confirm name
- [ ] Commitment tracking:
  - [ ] Save commitments to PersonStore linked to person + capture
  - [ ] `CommitmentStatus`: pending → completed / overdue
  - [ ] User can manually mark commitments as completed
- [ ] Relationship briefing generation:
  - [ ] When known face detected at start of capture, generate briefing
  - [ ] Include: last conversation summary, small talk suggestions, pending commitments
  - [ ] Use GPT fast model with person's fact history as context
  - [ ] Cache briefings for quick display (regenerate if stale)
- [ ] Briefing UI in `ConversationCaptureView`:
  - [ ] Card overlay during recording when known person recognized
  - [ ] Shows name, last conversation, key suggestions
  - [ ] "View Full Profile" and "Dismiss" buttons

---

## [ ] Milestone 17 (P1): People Directory UI

> **Goal:** Browseable directory of all recognized people with conversation history and relationship timeline.

- [ ] Create `PeopleView.swift`:
  - [ ] List of all PersonProfiles sorted by last seen
  - [ ] Search bar for filtering by name
  - [ ] Each row: reference photo, name, conversation count, last seen date
  - [ ] Badge for open commitments count
- [ ] Create `PersonDetailView.swift`:
  - [ ] Person header: photo, name, organization, role, relationship type
  - [ ] Editable fields: name, organization, role, relationship type
  - [ ] Personal facts section (grouped by category)
  - [ ] Commitments section (pending and completed)
  - [ ] Conversation timeline: list of all linked captures with date, title, duration
  - [ ] Tap capture → navigate to CaptureDetailView
- [ ] Create `CommitmentDashboardView.swift`:
  - [ ] Aggregate all open commitments across all people
  - [ ] Grouped by: "You owe them" / "They owe you" / "Mutual"
  - [ ] Sort by deadline or creation date
  - [ ] Swipe to mark as completed
- [ ] Add People tab to `ContentView.swift`:
  - [ ] New tab with `person.2` SF Symbol
  - [ ] Or integrate as section within Threads tab
- [ ] Update `CaptureDetailView.swift`:
  - [ ] Show linked person profiles below metadata
  - [ ] Show extracted commitments in summary tab

---

## [ ] Milestone 18 (P2): Proactive Intelligence & Knowledge Graph

> **Goal:** Proactive relationship prompts, commitment reminders, and Obsidian-style knowledge export.

- [ ] **Proactive briefing prompts:**
  - [ ] Local notification when you have overdue commitments with someone
  - [ ] "Reconnection" suggestions for people not seen in N weeks
  - [ ] Pre-meeting briefings triggered by calendar events (if calendar access granted)
- [ ] **Small talk intelligence:**
  - [ ] Track temporal facts ("going skiing next weekend" → expires after date)
  - [ ] Rank suggestions by relevance and recency
  - [ ] Deduplicate facts across conversations
- [ ] **Commitment reminders:**
  - [ ] Optional reminder date per commitment
  - [ ] Local notifications for upcoming/overdue commitments
  - [ ] Weekly digest: "You have 3 open commitments this week"
- [ ] **Cross-person insights:**
  - [ ] "Who have I discussed [topic] with?"
  - [ ] "Summarize all conversations with [person] this month"
  - [ ] Topic frequency analysis per person
- [ ] **Relationship health scoring:**
  - [ ] Track interaction frequency per person
  - [ ] Flag relationships going cold (no interaction in N weeks)
  - [ ] Visual indicator: green/yellow/red relationship health
- [ ] **Knowledge graph visualization (optional):**
  - [ ] Visual map of people ↔ topics ↔ conversations
  - [ ] Tap node to drill into details
- [ ] **Export (optional, low priority):**
  - [ ] Export person profiles as CSV
  - [ ] Export commitment list as shareable text
  - [ ] Obsidian vault format for power users (markdown with wiki-links)
- [ ] **Voice-triggered briefing (P2):**
  - [ ] "Hey Meta, who am I talking to?" → face recognition + spoken briefing
  - [ ] Extend Siri intents for relationship queries
