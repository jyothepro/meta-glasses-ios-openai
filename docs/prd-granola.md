# Product Requirements Document: Conversation Capture

**Product Name:** Conversation Capture (working title)
**Version:** 1.0
**Date:** February 25, 2026
**Author:** Product Team
**Status:** Draft

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Product Vision](#3-product-vision)
4. [Target Users](#4-target-users)
5. [Market Context & Competitive Landscape](#5-market-context--competitive-landscape)
6. [Product Requirements](#6-product-requirements)
7. [User Flows](#7-user-flows)
8. [Technical Architecture](#8-technical-architecture)
9. [Data Models](#9-data-models)
10. [API & Transcription Strategy](#10-api--transcription-strategy)
11. [Privacy & Consent Framework](#11-privacy--consent-framework)
12. [Constraints & Limitations](#12-constraints--limitations)
13. [Cost Analysis](#13-cost-analysis)
14. [Phased Rollout Plan](#14-phased-rollout-plan)
15. [Success Metrics](#15-success-metrics)
16. [Open Questions & Risks](#16-open-questions--risks)
17. [Relationship Intelligence](#17-relationship-intelligence)

---

## 1. Executive Summary

Conversation Capture brings Granola-style intelligent meeting transcription to **in-person conversations** via Meta Ray-Ban smart glasses. Where Granola excels at virtual meetings by recording computer audio without a bot, it fundamentally struggles with face-to-face interactions. Meta glasses solve this by providing an always-on, worn microphone that captures conversations naturally without awkward laptop-in-the-center setups.

The feature records audio via the glasses' HFP Bluetooth microphone, transcribes it in real-time or post-conversation, and uses AI to generate structured notes, action items, and searchable conversation history. Users can also take inline notes during conversations and have AI enhance them with full transcript context, exactly like Granola's core value proposition.

Beyond transcription, the system builds **Relationship Intelligence** — using the glasses camera to recognize who you're talking to, extracting personal details and commitments from conversations, and proactively surfacing relevant context the next time you meet someone. Think of it as a personal CRM that builds itself from your natural conversations: "Sarah mentioned skiing in Tahoe last week — good small talk opener" or "You promised Mike the report — follow up today."

This is not a replacement for the existing Voice Agent feature. Voice Agent is an **interactive AI assistant** (bidirectional conversation). Conversation Capture is a **passive listener** (unidirectional recording + post-processing). They serve different use cases and coexist as separate modes.

---

## 2. Problem Statement

### The Gap in Existing Tools

**Virtual meeting tools** (Granola, Otter.ai, Fireflies) work well for Zoom/Meet/Teams because they tap into clean, separated audio streams. But they fail for in-person conversations:

- Granola requires audio through your computer; the workaround is placing a MacBook in the center of a table
- Otter.ai and Fireflies require a "bot" to join a meeting link that doesn't exist for hallway chats
- Phone recording apps are socially awkward (holding up a phone signals "I'm recording you")
- No existing tool handles walking conversations, coffee chats, or impromptu meetings

### User Pain Points

1. **Information loss**: Important decisions, action items, and context from in-person conversations are forgotten within hours
2. **Note-taking friction**: Writing notes during a conversation breaks eye contact and social flow
3. **Context switching**: Switching between conversation and note-taking app reduces engagement quality
4. **Searchability**: Unlike emails and Slack messages, in-person conversations leave no searchable record
5. **Follow-up gaps**: Without clear action items, follow-ups from in-person meetings are frequently dropped

### Why Now

- Meta Ray-Ban Gen 2 glasses doubled battery life to **8 hours** (5 hours continuous audio), making all-day wear viable
- On-device transcription (WhisperKit) has reached production quality on Apple Silicon
- Our app already has the complete audio capture and conversation persistence infrastructure
- Granola's $250M valuation validates the market for AI-enhanced meeting notes

---

## 3. Product Vision

### Vision Statement

> Make every important conversation actionable, without changing how you have conversations.

### Core Principles

1. **Invisible capture**: Recording should require zero behavioral change. You wear your glasses and talk normally.
2. **Note enhancement, not replacement**: Like Granola, we enhance your rough notes with full transcript context rather than dumping raw transcripts.
3. **Privacy by design**: Consent and transparency are first-class features, not afterthoughts.
4. **Offline-first**: Core functionality works without network. AI enhancement happens when connected.
5. **Conversation memory**: Over time, the system builds a searchable knowledge base of your professional interactions.

### What This Is NOT

- Not a surveillance tool (requires explicit start/stop)
- Not a real-time AI assistant (that's Voice Agent mode)
- Not a phone call recorder (separate regulatory domain)
- Not a meeting bot (no virtual meeting integration in v1)

---

## 4. Target Users

### Primary Persona: The Connector

**Profile:** Professionals whose work revolves around in-person interactions
- Sales reps doing client visits and site walkthroughs
- Consultants in on-site workshops and stakeholder interviews
- Executives in back-to-back meetings, hallway decisions, and dinner conversations
- Founders doing customer discovery through face-to-face interviews
- Journalists conducting in-person interviews

**Behavioral Traits:**
- Has 5-10+ meaningful conversations per day
- Frequently forgets specifics discussed 2+ days ago
- Currently uses a mix of mental notes, phone notes app, and memory
- Values relationships and doesn't want technology to create social friction

### Secondary Persona: The Learner

**Profile:** Individuals in high-information-density environments
- Medical professionals in patient consultations (with consent)
- Students in office hours, study groups, and lab meetings
- Researchers conducting field interviews
- New employees during onboarding conversations

### Anti-Persona: The Surveiller

**Profile:** Users who want to record others without knowledge or consent
- This is explicitly not our target user
- The product design actively discourages covert recording
- Consent mechanisms are mandatory, not optional

---

## 5. Market Context & Competitive Landscape

### Direct Competitors

| Product | Strengths | Weakness for In-Person |
|---------|-----------|----------------------|
| **Granola** ($250M valuation) | No-bot approach, note enhancement, beautiful UX | Requires computer audio; in-person is a workaround |
| **Otter.ai** | Real-time transcription, speaker ID | Needs meeting link or phone app; socially awkward |
| **Fireflies.ai** | Automated notes, CRM integration | Bot-based; no in-person support |
| **Plaud Note** | Dedicated recording hardware | Separate device to carry; no glasses integration |
| **Limitless Pendant** | Wearable form factor | Another device to wear; no visual capture |

### Our Unique Position

| Differentiator | Why It Matters |
|---------------|---------------|
| **Already worn** | Glasses are a natural accessory; no additional hardware |
| **Visual context** | Can capture whiteboards, documents, environments (unique to glasses) |
| **Proximity advantage** | Mic near mouth provides natural self/other audio separation |
| **Existing AI ecosystem** | Voice Agent, memories, and thread history create compound value |
| **Mobile** | Works in any physical context: walks, dinners, site visits, not just conference rooms |

### Market Validation

- Granola raised $43M at $250M valuation (May 2025) for AI meeting notes
- Limitless raised $12M for a wearable AI pendant
- Plaud raised $10M for an AI voice recorder
- Combined TAM for meeting productivity tools: $15B+ by 2027

---

## 6. Product Requirements

### 6.1 MVP Requirements (P0)

#### 6.1.1 Capture Mode

| Req ID | Requirement | Details |
|--------|-------------|---------|
| P0-01 | Start/stop capture | Manual tap-to-start in app; tap-to-stop to end capture session |
| P0-02 | Audio recording | Record from glasses HFP mic to local M4A file via existing `AudioManager` |
| P0-03 | Capture indicator | Clear visual indicator in app showing active capture (elapsed time, audio level) |
| P0-04 | Background capture | Audio continues recording when app is backgrounded (background audio entitlement) |
| P0-05 | Idle timer disabled | Prevent device sleep during active capture (existing pattern from Voice Agent) |

#### 6.1.2 Transcription

| Req ID | Requirement | Details |
|--------|-------------|---------|
| P0-06 | Post-capture transcription | After capture ends, transcribe full audio via Whisper API or Deepgram |
| P0-07 | Transcription progress | Show progress indicator during transcription (% complete or time remaining) |
| P0-08 | Transcript display | Show full transcript in scrollable view with timestamps |
| P0-09 | Transcript persistence | Store transcript alongside thread in local storage |
| P0-10 | Fallback mic | If glasses not connected, allow capture from device built-in microphone |

#### 6.1.3 AI Processing

| Req ID | Requirement | Details |
|--------|-------------|---------|
| P0-11 | Conversation summary | Generate structured summary: key points, decisions, action items |
| P0-12 | Thread creation | Save capture as a new thread in existing Threads system |
| P0-13 | Auto-title | Generate descriptive title from transcript content (existing pattern) |

#### 6.1.4 History & Retrieval

| Req ID | Requirement | Details |
|--------|-------------|---------|
| P0-14 | Thread list | Captured conversations appear in existing Threads tab |
| P0-15 | Thread detail | View transcript, summary, and any inline notes for past captures |
| P0-16 | Delete capture | Delete thread and associated audio/transcript files |

### 6.2 Post-MVP Requirements (P1)

| Req ID | Requirement | Details |
|--------|-------------|---------|
| P1-01 | Real-time transcription | Stream audio to transcription API during capture for live transcript |
| P1-02 | Inline notes | Text input during capture; AI enhances notes with transcript context post-capture (Granola's core feature) |
| P1-03 | Chat with transcript | Ask questions about any past conversation ("What did they say about budget?") |
| P1-04 | Speaker labels | Distinguish "You" vs "Other(s)" using audio proximity heuristics |
| P1-05 | Consent prompt | Show/speak a consent notice at capture start ("This conversation is being recorded") |
| P1-06 | Smart pause/resume | Detect silence gaps and auto-pause recording to save battery and storage |
| P1-07 | Photo snapshots | Capture photos during conversation (whiteboard, business card, document) linked to transcript timestamp |
| P1-08 | Export | Share transcript/summary as text, PDF, or to other apps (Notes, Notion, etc.) |
| P1-09 | Search | Full-text search across all captured conversation transcripts |

#### 6.2.2 Relationship Intelligence (P1)

| Req ID | Requirement | Details |
|--------|-------------|---------|
| P1-10 | Person photo capture | During capture, snap photos of conversation partners via glasses camera (manual button or periodic auto-capture) |
| P1-11 | Person profile creation | Create person profiles from captured photos with face embedding, name (extracted from transcript or manual entry), and linked capture history |
| P1-12 | Face recognition matching | Match faces across encounters using on-device face embeddings (Apple Vision + Core ML); link new captures to existing person profiles |
| P1-13 | Relationship briefing | When a known person is recognized at start of capture, surface a briefing: last conversation summary, key topics, and pending follow-ups |
| P1-14 | Commitment extraction | AI extracts commitments from transcripts: things you promised them, things they promised you, with deadlines if mentioned |
| P1-15 | People directory | Browseable directory of all recognized people with conversation history, key facts, and relationship timeline |

### 6.3 Future Requirements (P2)

| Req ID | Requirement | Details |
|--------|-------------|---------|
| P2-01 | On-device transcription | WhisperKit for fully offline transcription (no network needed) |
| P2-02 | Multi-speaker diarization | Identify and label individual speakers by voice profile |
| P2-03 | Cross-conversation insights | "What topics came up most this week?" / "Summarize all conversations with [person]" |
| P2-04 | Calendar integration | Link captures to calendar events; auto-start at meeting time |
| P2-05 | CRM/tool integration | Push summaries to Notion, Salesforce, HubSpot, etc. |
| P2-06 | Action item tracking | Track action items across conversations; remind on follow-ups |
| P2-07 | Conversation templates | Pre-defined structures for common conversation types (1:1, interview, sales call) |
| P2-08 | Voice-triggered start | "Hey Meta, start capturing" to begin recording without opening app |

#### 6.3.2 Relationship Intelligence (P2)

| Req ID | Requirement | Details |
|--------|-------------|---------|
| P2-09 | Proactive small talk prompts | Before/during a conversation with a known person, surface personal details they shared previously as small talk suggestions ("Ask about their skiing trip to Colorado") |
| P2-10 | Commitment tracking & reminders | Track fulfillment status of extracted commitments; local notification reminders for overdue items; dashboard of open commitments per person |
| P2-11 | People knowledge graph | Visual graph of people, topics, and conversations showing relationship connections; Obsidian-style linked notes between people and encounters |
| P2-12 | Cross-person insights | "Who have I discussed [topic] with?" / "Summarize all my conversations with [person] this month" / "What topics come up most with [person]?" |
| P2-13 | Export (optional) | Export person profiles and relationship history as markdown, CSV, or Notion pages. Obsidian vault format with wiki-links for power users. Low priority — core value is in-app. |
| P2-14 | Voice-triggered briefing | "Hey Meta, who am I talking to?" triggers face recognition + relationship briefing spoken through glasses speakers |
| P2-15 | Relationship health scoring | Track interaction frequency per person; flag relationships going cold; suggest reconnection for people not seen in N weeks |

---

## 7. User Flows

### 7.1 MVP: Basic Capture Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        CAPTURE FLOW (MVP)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  User opens app                                                 │
│       │                                                         │
│       ▼                                                         │
│  ┌─────────────┐                                                │
│  │ Capture Tab  │  (New tab alongside Voice Agent & Threads)    │
│  │             │                                                │
│  │  [ START ]  │  Big, prominent capture button                 │
│  │             │                                                │
│  │  Glasses: ✓ │  Shows mic source (glasses or device)         │
│  └──────┬──────┘                                                │
│         │ Tap START                                              │
│         ▼                                                       │
│  ┌──────────────┐                                               │
│  │  RECORDING   │                                               │
│  │              │                                               │
│  │  ● 00:12:34  │  Elapsed time + pulsing indicator            │
│  │  ▁▂▃▅▃▂▁    │  Audio level visualization                   │
│  │              │                                               │
│  │  Mic: Glasses│  Audio source indicator                      │
│  │              │                                               │
│  │  [ ■ STOP ] │  Stop button                                  │
│  └──────┬──────┘                                                │
│         │ Tap STOP                                              │
│         ▼                                                       │
│  ┌──────────────┐                                               │
│  │ PROCESSING   │                                               │
│  │              │                                               │
│  │ Transcribing │  Progress indicator                          │
│  │ ████░░ 67%  │                                               │
│  └──────┬──────┘                                                │
│         │ Complete                                               │
│         ▼                                                       │
│  ┌──────────────────────────────────────────────────┐           │
│  │  CAPTURE RESULT                                   │           │
│  │                                                   │           │
│  │  "Q1 Planning Discussion"  (auto-generated title) │           │
│  │  Feb 25, 2026 · 12 min · 2,847 words             │           │
│  │                                                   │           │
│  │  ┌─ SUMMARY ──────────────────────┐               │           │
│  │  │ • Agreed to launch by March 15 │               │           │
│  │  │ • Budget approved at $50K      │               │           │
│  │  │ • Sarah owns design, Mike owns │               │           │
│  │  │   eng implementation           │               │           │
│  │  └────────────────────────────────┘               │           │
│  │                                                   │           │
│  │  ┌─ ACTION ITEMS ────────────────┐                │           │
│  │  │ □ Sarah: Finalize mockups     │                │           │
│  │  │ □ Mike: Set up staging env    │                │           │
│  │  │ □ You: Send follow-up email   │                │           │
│  │  └────────────────────────────────┘               │           │
│  │                                                   │           │
│  │  ┌─ TRANSCRIPT ──────────────────┐                │           │
│  │  │ [0:00] So let's talk about    │                │           │
│  │  │ the Q1 plan...                │                │           │
│  │  │ [0:15] Right, I think we      │                │           │
│  │  │ should focus on...            │                │           │
│  │  │ ...                           │                │           │
│  │  └────────────────────────────────┘               │           │
│  │                                                   │           │
│  │  [ View in Threads ]  [ New Capture ]             │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 P1: Enhanced Capture with Inline Notes

```
┌─────────────────────────────────────────────────────────────────┐
│                   ENHANCED CAPTURE (P1)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────┐           │
│  │  RECORDING    ● 00:08:22                          │           │
│  │                                                   │           │
│  │  ┌─ LIVE TRANSCRIPT ─────────────┐                │           │
│  │  │ ...they mentioned the budget  │ (scrolling)    │
│  │  │ would need to be around 50K   │                │           │
│  │  │ for the initial phase...      │                │           │
│  │  └────────────────────────────────┘               │           │
│  │                                                   │           │
│  │  ┌─ YOUR NOTES ──────────────────┐                │           │
│  │  │ - budget 50k approved         │ (user types)   │
│  │  │ - sarah owns design           │                │           │
│  │  │ - launch target march 15      │                │           │
│  │  │ |                             │                │           │
│  │  └────────────────────────────────┘               │           │
│  │                                                   │           │
│  │  📷 [Snap]   [ ■ STOP ]                          │           │
│  └──────────────────────────────────────────────────┘           │
│         │                                                       │
│         │ After STOP + AI Processing                            │
│         ▼                                                       │
│  ┌──────────────────────────────────────────────────┐           │
│  │  ENHANCED NOTES (Granola-style)                   │           │
│  │                                                   │           │
│  │  Your rough notes, enriched with transcript:      │           │
│  │                                                   │           │
│  │  • **Budget: $50K approved** for initial phase.   │           │
│  │    Team agreed this covers infrastructure and     │           │
│  │    two contractor hires. Mike to submit PO by     │           │
│  │    Friday.                                        │           │
│  │                                                   │           │
│  │  • **Sarah owns design** — delivering mockups     │           │
│  │    by March 1st. Will use existing component      │           │
│  │    library. Mentioned concerns about mobile       │           │
│  │    responsiveness timeline.                       │           │
│  │                                                   │           │
│  │  • **Launch target: March 15** — aggressive but   │           │
│  │    feasible if eng starts by Feb 28. Fallback     │           │
│  │    date is March 22 if design review takes        │           │
│  │    longer than expected.                          │           │
│  │                                                   │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.3 P1: Chat with Transcript

```
┌─────────────────────────────────────────────────────────────────┐
│                   CHAT WITH TRANSCRIPT (P1)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Thread: "Q1 Planning Discussion"                               │
│  ┌──────────────────────────────────────────────────┐           │
│  │                                                   │           │
│  │  [Summary]  [Transcript]  [Chat]  ← tab selector │           │
│  │                                                   │           │
│  │  You: What was the fallback launch date?          │           │
│  │                                                   │           │
│  │  AI: The fallback launch date discussed was       │           │
│  │  March 22, in case the design review takes        │           │
│  │  longer than expected. [0:08:34]                  │           │
│  │                                                   │           │
│  │  You: Did anyone mention testing?                 │           │
│  │                                                   │           │
│  │  AI: Testing wasn't explicitly discussed in       │           │
│  │  this conversation. You may want to follow up     │           │
│  │  with Mike about the QA timeline.                 │           │
│  │                                                   │           │
│  │  ┌──────────────────────────────┐                 │           │
│  │  │ Ask about this conversation  │  [Send]         │           │
│  │  └──────────────────────────────┘                 │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.4 P1/P2: Relationship Intelligence Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              RELATIONSHIP INTELLIGENCE FLOW                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ── FIRST ENCOUNTER ─────────────────────────────────────────── │
│                                                                  │
│  User starts capture                                             │
│       │                                                          │
│       ▼                                                          │
│  ┌──────────────────────────────────────────────────┐            │
│  │  RECORDING     ● 00:05:22                         │            │
│  │                                                    │            │
│  │  ┌─────────────────────────────────────────────┐  │            │
│  │  │  📷 [Snap Person]          Auto: Every 2min │  │            │
│  │  └─────────────────────────────────────────────┘  │            │
│  │                                                    │            │
│  │  Person captured! Creating profile...              │            │
│  │  ┌─────────────┐                                  │            │
│  │  │  👤 ██████  │  "New person detected"           │            │
│  │  │  (photo)    │  Name: [extracting from          │            │
│  │  │             │   conversation...]               │            │
│  │  └─────────────┘                                  │            │
│  └──────────────────────────────────────────────────┘            │
│       │                                                          │
│       │ After stop + AI processing                               │
│       ▼                                                          │
│  ┌──────────────────────────────────────────────────┐            │
│  │  PERSON PROFILE CREATED                           │            │
│  │                                                    │            │
│  │  👤 "Sarah Chen"  (name from transcript)          │            │
│  │  Met: Feb 26, 2026 at Coffee Shop                 │            │
│  │                                                    │            │
│  │  Key Facts Extracted:                              │            │
│  │  • Works at Acme Corp, Design Lead                │            │
│  │  • Has two kids (mentioned soccer practice)        │            │
│  │  • Going skiing in Tahoe next weekend              │            │
│  │                                                    │            │
│  │  Commitments:                                      │            │
│  │  📤 You → Her: "Send the mockup feedback"         │            │
│  │  📥 Her → You: "Intro to their CTO next week"    │            │
│  │                                                    │            │
│  │  Topics: [design] [budget] [Q2 launch]            │            │
│  └──────────────────────────────────────────────────┘            │
│                                                                  │
│  ── SUBSEQUENT ENCOUNTER (next day) ────────────────────────── │
│                                                                  │
│  User starts capture → glasses see a face                        │
│       │                                                          │
│       ▼                                                          │
│  ┌──────────────────────────────────────────────────┐            │
│  │  🔔 RELATIONSHIP BRIEFING                         │            │
│  │                                                    │            │
│  │  👤 "Sarah Chen" recognized                       │            │
│  │  Last spoke: Yesterday (Coffee Shop, 12 min)      │            │
│  │                                                    │            │
│  │  ┌─ SMALL TALK SUGGESTIONS ──────────────────┐    │            │
│  │  │ 💬 "Ask about her skiing trip to Tahoe     │    │            │
│  │  │    this weekend"                           │    │            │
│  │  │ 💬 "Ask how her kids' soccer is going"     │    │            │
│  │  └────────────────────────────────────────────┘    │            │
│  │                                                    │            │
│  │  ┌─ PENDING FOLLOW-UPS ──────────────────────┐    │            │
│  │  │ ⚠️ You promised: Send mockup feedback      │    │            │
│  │  │    (not yet done)                          │    │            │
│  │  │ 📥 Ask her: Intro to CTO (she promised)   │    │            │
│  │  └────────────────────────────────────────────┘    │            │
│  │                                                    │            │
│  │  ┌─ LAST CONVERSATION SUMMARY ───────────────┐    │            │
│  │  │ Discussed Q2 launch timeline, agreed on    │    │            │
│  │  │ $50K budget. Sarah owns design, delivery   │    │            │
│  │  │ by March 15.                               │    │            │
│  │  └────────────────────────────────────────────┘    │            │
│  │                                                    │            │
│  │  [ Dismiss ]  [ View Full History ]               │            │
│  └──────────────────────────────────────────────────┘            │
│                                                                  │
│  ── PEOPLE DIRECTORY ────────────────────────────────────────── │
│                                                                  │
│  ┌──────────────────────────────────────────────────┐            │
│  │  PEOPLE                              🔍 Search    │            │
│  │                                                    │            │
│  │  Recent                                            │            │
│  │  ┌─────┐                                          │            │
│  │  │👤   │ Sarah Chen · 3 conversations             │            │
│  │  │     │ Last: Yesterday · Design, Budget          │            │
│  │  ├─────┤                                          │            │
│  │  │👤   │ Mike Rodriguez · 7 conversations         │            │
│  │  │     │ Last: 2 days ago · Engineering            │            │
│  │  ├─────┤                                          │            │
│  │  │👤   │ Unknown Person · 1 conversation          │            │
│  │  │     │ Last: 3 days ago · Coffee chat            │            │
│  │  └─────┘                                          │            │
│  │                                                    │            │
│  │  ⚠️ 2 open commitments need follow-up             │            │
│  └──────────────────────────────────────────────────┘            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Technical Architecture

### 8.1 System Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                         META GLASSES                                   │
│  ┌──────────┐                                                          │
│  │ 5-Mic    │──── HFP Bluetooth ────┐                                  │
│  │ Array    │                       │                                  │
│  ├──────────┤                       │                                  │
│  │ Camera   │──── BLE Stream ───────┤                                  │
│  └──────────┘                       │                                  │
└─────────────────────────────────────┤                                  │
                                      │                                  │
┌─────────────────────────────────────▼──────────────────────────────────┐
│                           iOS APP                                      │
│                                                                        │
│  ┌─────────────────────────────────────────────────────────┐           │
│  │              ConversationCaptureManager                  │           │
│  │  ┌─────────┐  ┌───────────┐  ┌──────────────────────┐  │           │
│  │  │ Capture  │  │ Inline    │  │ State Machine        │  │           │
│  │  │ Control  │  │ Notes     │  │ idle → recording →   │  │           │
│  │  │          │  │ Editor    │  │ processing → complete │  │           │
│  │  └────┬─────┘  └─────┬─────┘  └──────────────────────┘  │           │
│  │       │              │                                   │           │
│  └───────┼──────────────┼───────────────────────────────────┘           │
│          │              │                                              │
│  ┌───────▼──────┐  ┌───▼────────────────────────────────────┐         │
│  │ AudioManager │  │ Local Storage (Documents/)              │         │
│  │ (existing)   │  │  ├── captures/                          │         │
│  │              │  │  │   ├── [uuid].m4a    (audio file)     │         │
│  │ HFP Config   │  │  │   ├── [uuid].json   (transcript)    │         │
│  │ M4A Record   │  │  │   └── [uuid]_notes.txt (user notes) │         │
│  └──────────────┘  │  ├── threads.json      (extended)       │         │
│                    │  └── captures_index.json (metadata)     │         │
│                    └─────────────────────────────────────────┘         │
│                                                                        │
│                    ┌─────────────────────────────────────────┐         │
│                    │         Network Services                 │         │
│                    │  ┌───────────┐  ┌───────────────────┐   │         │
│                    │  │ Whisper   │  │ GPT-4o-mini       │   │         │
│                    │  │ API       │  │ (summary/enhance) │   │         │
│                    │  │           │  │                   │   │         │
│                    │  │ or        │  │ or                │   │         │
│                    │  │ Deepgram  │  │ GPT-4o            │   │         │
│                    │  │ WebSocket │  │ (chat w/transcript│   │         │
│                    │  └───────────┘  └───────────────────┘   │         │
│                    └─────────────────────────────────────────┘         │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 8.2 New Components

#### ConversationCaptureManager

The primary new class. Follows existing singleton + `@MainActor` + `ObservableObject` patterns.

**Responsibilities:**
- Capture lifecycle management (start, stop, pause, resume)
- Audio recording orchestration via existing `AudioManager`
- Transcription pipeline (send audio to API, receive text)
- AI post-processing coordination (summary, enhancement)
- Capture metadata persistence
- State publishing for UI reactivity

**State Machine:**

```
     ┌──────┐   start()   ┌───────────┐   stop()   ┌────────────┐
     │ idle │────────────▶│ recording │───────────▶│ processing │
     └──────┘             └───────────┘             └─────┬──────┘
        ▲                      │                          │
        │                      │ cancel()                 │ complete
        │                      ▼                          ▼
        │                 ┌──────────┐             ┌───────────┐
        └─────────────────│ idle     │◀────────────│ completed │
                          └──────────┘             └───────────┘
```

**Published Properties:**
- `captureState: CaptureState` — `.idle | .recording | .processing | .completed(CaptureResult) | .error(String)`
- `elapsedTime: TimeInterval` — seconds since recording started
- `audioLevel: Float` — real-time mic level (0.0 to 1.0)
- `currentTranscript: String` — live transcript (P1, empty in MVP)
- `inlineNotes: String` — user-typed notes during capture
- `audioSource: String` — "Meta Glasses" or "Device Microphone"

#### ConversationCaptureView

New SwiftUI view for the Capture tab.

**Sections:**
1. **Pre-capture:** Source indicator, recent captures list, start button
2. **During capture:** Timer, audio level, notes editor (P1), live transcript (P1), stop button
3. **Post-capture processing:** Transcription progress
4. **Result:** Summary, action items, transcript, notes (tabbed view)

#### CaptureDetailView

Detail view for reviewing past captures from Threads tab.

**Sections:**
- Summary tab (key points, decisions, action items)
- Transcript tab (timestamped full text)
- Notes tab (user notes, enhanced notes in P1)
- Chat tab (P1: ask questions about the conversation)

#### PersonManager (P1 — Relationship Intelligence)

New singleton managing person profiles and face recognition.

**Responsibilities:**
- Face detection and embedding generation (on-device)
- Person profile CRUD operations
- Face matching across encounters (cosine similarity)
- Relationship intelligence extraction from transcripts
- Commitment tracking and briefing generation

**Key Components:**

```
┌─────────────────────────────────────────────────────────┐
│                    PersonManager                         │
│                                                          │
│  ┌──────────────────┐  ┌──────────────────────────────┐ │
│  │ FaceRecognition   │  │ RelationshipIntelligence     │ │
│  │ Engine            │  │ Engine                       │ │
│  │                    │  │                              │ │
│  │ • Apple Vision     │  │ • Extract person details     │ │
│  │   face detection   │  │ • Extract commitments        │ │
│  │ • Core ML face     │  │ • Generate briefings         │ │
│  │   embeddings       │  │ • Suggest small talk         │ │
│  │ • Cosine similarity│  │ • Track follow-ups           │ │
│  │   matching         │  │                              │ │
│  └──────────────────┘  └──────────────────────────────┘ │
│                                                          │
│  ┌──────────────────────────────────────────────────────┐│
│  │ PersonStore (local JSON persistence)                  ││
│  │ • people_index.json  (profiles + face embeddings)     ││
│  │ • [person_uuid]/     (photos, relationship data)      ││
│  └──────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

**Face Recognition Pipeline (all on-device, no cloud):**

```
Glasses Photo
      │
      ▼
┌─────────────┐   Apple Vision Framework
│ Face         │   VNDetectFaceRectanglesRequest
│ Detection    │   → Finds face bounding boxes in image
└──────┬──────┘
       │
       ▼
┌─────────────┐   Core ML (ArcFace/MobileFaceNet ~10MB)
│ Face         │   → Generates 128/512-dim embedding vector
│ Embedding    │   → All on-device, no network needed
└──────┬──────┘
       │
       ▼
┌─────────────┐   Cosine similarity against stored embeddings
│ Face         │   → Match threshold: 0.6-0.7 similarity
│ Matching     │   → Returns: matched PersonProfile or "new person"
└──────┬──────┘
       │
       ├─── Known person → Load profile → Generate briefing
       │
       └─── New person → Create profile → Extract details from transcript
```

### 8.3 Reusing Existing Infrastructure

| Existing Component | Reuse Strategy |
|---|---|
| `AudioManager` | Direct reuse for HFP config, M4A recording, mic detection |
| `ThreadsManager` | Extend data model to support capture-type threads |
| `SettingsManager` | Add capture-specific settings (default transcription provider, auto-summary) |
| `SoundManager` | Reuse for capture start/stop audio cues |
| `GlassesManager` | Reuse for glasses connection status, photo capture (P1) |
| `TextInputBar` | Reuse for inline notes during capture |
| `APIDebugLogger` | Log all transcription and processing API calls |
| `ContentView` TabView | Add fourth tab for Capture |

### 8.4 File System Layout

```
Documents/
├── threads.json                    # Extended with capture threads
├── captures_index.json             # Capture metadata index
├── captures/
│   ├── [uuid]/
│   │   ├── audio.m4a               # Raw audio recording
│   │   ├── transcript.json         # Full timestamped transcript
│   │   ├── summary.json            # AI-generated summary + action items
│   │   ├── notes.txt               # User inline notes (raw)
│   │   ├── enhanced_notes.json     # AI-enhanced notes (P1)
│   │   └── photos/                 # Snapshot photos linked to timestamps (P1)
│   │       ├── [timestamp].jpg
│   │       └── ...
│   └── [uuid]/
│       └── ...
├── people/                         # P1: Relationship Intelligence
│   ├── people_index.json           # Person profiles + face embeddings
│   ├── [person_uuid]/
│   │   ├── profile.json            # Full person profile
│   │   ├── face_reference.jpg      # Best reference photo
│   │   ├── commitments.json        # Tracked commitments
│   │   └── briefing_cache.json     # Pre-generated briefing
│   └── [person_uuid]/
│       └── ...
├── settings.json
└── captured_media.json
```

---

## 9. Data Models

### 9.1 Core Models

```swift
// Capture session metadata
struct CaptureSession: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var title: String                    // AI-generated from transcript
    var duration: TimeInterval           // Recording duration in seconds
    var audioFilePath: String            // Relative path to M4A file
    var transcriptStatus: TranscriptStatus
    var summaryStatus: SummaryStatus
    var audioSource: AudioSource         // .glasses or .deviceMic
    var wordCount: Int                   // Total words in transcript
    var location: String?                // Location at time of capture
}

enum TranscriptStatus: String, Codable {
    case pending                         // Not yet transcribed
    case inProgress                      // Transcription running
    case completed                       // Transcript available
    case failed                          // Transcription error
}

enum SummaryStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case failed
}

enum AudioSource: String, Codable {
    case glasses
    case deviceMic
}
```

```swift
// Timestamped transcript
struct Transcript: Codable {
    let captureId: UUID
    let segments: [TranscriptSegment]
    let fullText: String                 // Concatenated text for search
    let language: String                 // Detected language
    let provider: String                 // "whisper" or "deepgram"
}

struct TranscriptSegment: Codable {
    let startTime: TimeInterval          // Seconds from recording start
    let endTime: TimeInterval
    let text: String
    let speaker: SpeakerLabel?           // P1: speaker diarization
    let confidence: Float?               // 0.0 to 1.0
}

enum SpeakerLabel: String, Codable {
    case user                            // Glasses wearer (louder/closer)
    case other                           // Other participant(s)
    case unknown
}
```

```swift
// AI-generated summary
struct CaptureSummary: Codable {
    let captureId: UUID
    let keyPoints: [String]              // Bullet points of key topics
    let decisions: [String]              // Decisions made
    let actionItems: [ActionItem]        // Tasks with assignees
    let sentiment: String?               // Overall conversation tone
    let topics: [String]                 // Topic tags for categorization
}

struct ActionItem: Codable {
    let description: String
    let assignee: String?                // Person responsible (if mentioned)
    let deadline: String?                // Due date (if mentioned)
    var isCompleted: Bool = false         // User can check off
}
```

```swift
// Enhanced notes (P1 - Granola-style)
struct EnhancedNotes: Codable {
    let captureId: UUID
    let rawNotes: String                 // User's original inline notes
    let enhancedContent: String          // AI-enhanced markdown
    let enhancedAt: Date
}
```

### 9.2 Relationship Intelligence Models (P1/P2)

```swift
// Person profile — built from face recognition + AI transcript extraction
struct PersonProfile: Identifiable, Codable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var name: String                      // Extracted from transcript or manual entry
    var nameSource: NameSource            // .transcript, .manual, .unknown
    var faceEmbedding: [Float]?           // 128/512-dim vector from Core ML model
    var referencePhotoPath: String?       // Best quality face photo
    var organization: String?             // Company/org if mentioned
    var role: String?                     // Job title if mentioned
    var personalFacts: [PersonalFact]     // Things they've shared about themselves
    var captureIds: [UUID]                // All captures involving this person
    var relationshipType: RelationshipType?  // .colleague, .client, .friend, etc.
    var lastSeenAt: Date?
    var totalConversationTime: TimeInterval  // Sum of all linked capture durations
    var conversationCount: Int
}

enum NameSource: String, Codable {
    case transcript                       // AI extracted from conversation
    case manual                           // User typed it in
    case unknown                          // Not yet identified
}

enum RelationshipType: String, Codable, CaseIterable {
    case colleague
    case client
    case friend
    case acquaintance
    case other
}

// Facts about a person extracted from conversations
struct PersonalFact: Identifiable, Codable {
    let id: UUID
    let fact: String                      // "Has two kids who play soccer"
    let captureId: UUID                   // Which conversation this came from
    let extractedAt: Date
    var category: FactCategory
}

enum FactCategory: String, Codable {
    case family                           // Kids, spouse, parents
    case work                             // Role, projects, company
    case interests                        // Hobbies, travel, sports
    case plans                            // Upcoming events, trips
    case preferences                      // Likes, dislikes
    case other
}

// Commitments extracted from conversations
struct Commitment: Identifiable, Codable {
    let id: UUID
    let captureId: UUID                   // Which conversation
    let personId: UUID                    // Who's involved
    let description: String               // "Send the mockup feedback"
    let direction: CommitmentDirection     // Who promised whom
    var status: CommitmentStatus
    let deadline: String?                 // If mentioned
    let extractedAt: Date
    var completedAt: Date?
    var reminderDate: Date?               // Optional reminder
}

enum CommitmentDirection: String, Codable {
    case youToThem                         // "I'll send you the report"
    case themToYou                         // "I'll introduce you to our CTO"
    case mutual                            // "Let's meet again next week"
}

enum CommitmentStatus: String, Codable {
    case pending                           // Not yet fulfilled
    case completed                         // Marked as done
    case overdue                           // Past deadline
    case cancelled                         // No longer relevant
}

// Relationship briefing — generated when a known person is recognized
struct RelationshipBriefing: Codable {
    let personId: UUID
    let generatedAt: Date
    let lastConversationSummary: String?   // Summary of most recent capture
    let smallTalkSuggestions: [String]      // "Ask about skiing trip"
    let pendingCommitments: [Commitment]   // Open items to follow up
    let keyTopics: [String]                // Recurring topics with this person
    let conversationHistory: [BriefingCapture]  // Recent captures timeline
}

struct BriefingCapture: Codable {
    let captureId: UUID
    let date: Date
    let title: String
    let durationMinutes: Int
    let topicSummary: String               // One-line summary
}
```

### 9.3 CaptureSession Extension (Relationship Link)

```swift
// Add to existing CaptureSession:
struct CaptureSession {
    // ... existing fields ...
    var personIds: [UUID]                 // P1: People involved in this capture
    var commitmentIds: [UUID]             // P1: Commitments extracted from this capture
}
```

### 9.4 Thread Extension

Extend the existing `ConversationThread` model to support capture threads:

```swift
struct ConversationThread: Codable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var title: String
    var messages: [StoredMessage]
    var threadType: ThreadType           // NEW: .voiceAgent or .capture
    var captureId: UUID?                 // NEW: links to CaptureSession
}

enum ThreadType: String, Codable {
    case voiceAgent                      // Existing interactive conversations
    case capture                         // New passive capture sessions
}
```

### 9.5 Settings Extension

```swift
struct AppSettings: Codable {
    // ... existing fields ...

    // Capture settings (NEW)
    var captureTranscriptionProvider: TranscriptionProvider
    var captureAutoSummary: Bool          // Auto-generate summary after transcription
    var captureConsentPrompt: Bool        // Show consent notice at start
    var captureDefaultMicSource: MicSource
}

enum TranscriptionProvider: String, Codable {
    case whisperAPI                       // OpenAI Whisper ($0.006/min)
    case deepgram                        // Deepgram Nova-3 ($0.0077/min)
    case whisperKit                      // On-device (free, P2)
}

enum MicSource: String, Codable {
    case glasses                         // Prefer glasses HFP mic
    case device                          // Use device built-in mic
    case auto                            // Glasses if connected, else device
}
```

---

## 10. API & Transcription Strategy

### 10.1 Transcription Provider Comparison

| Provider | Cost/min | Latency | Quality | Streaming | Offline | Notes |
|----------|----------|---------|---------|-----------|---------|-------|
| **Whisper API** | $0.006 | Batch (post-capture) | Excellent | No native | No | Best accuracy; our app already has OpenAI key |
| **Deepgram Nova-3** | $0.0077 | Real-time | Very Good | Yes (WebSocket) | No | Best for live transcript (P1); $200 free credits |
| **WhisperKit** | Free | Real-time | Good | On-device | Yes | Best for P2 offline; requires ~500MB model download |

### 10.2 Recommended Strategy

**MVP:** Whisper API (batch transcription after recording ends)
- Simplest integration: upload M4A file, receive transcript
- Already have OpenAI API key configured in app
- Best transcription accuracy
- No additional SDK dependencies

**P1:** Add Deepgram as real-time option
- WebSocket streaming for live transcript during capture
- Similar architecture to existing `RealtimeAPIClient` WebSocket
- User can choose provider in Settings

**P2:** Add WhisperKit for offline
- On-device transcription with no network required
- Swift Package Manager integration
- Model download on first use (~500MB)

### 10.3 Whisper API Integration (MVP)

```
Recording Complete
       │
       ▼
┌──────────────┐     POST /v1/audio/transcriptions
│ M4A Audio    │────────────────────────────────────▶ OpenAI Whisper API
│ File         │                                     │
│ (local)      │     { text, segments[], language }   │
│              │◀────────────────────────────────────┘
└──────────────┘
       │
       ▼
┌──────────────┐     POST /v1/chat/completions (gpt-4o-mini)
│ Transcript   │────────────────────────────────────▶ OpenAI Chat API
│ + User Notes │                                     │
│              │     { summary, action_items, ... }   │
│              │◀────────────────────────────────────┘
└──────────────┘
       │
       ▼
  Save to local storage
```

**Whisper API Request:**
- Endpoint: `POST https://api.openai.com/v1/audio/transcriptions`
- Model: `whisper-1`
- File: M4A audio file (max 25MB = ~90 min at M4A quality)
- Response format: `verbose_json` (includes timestamps per segment)
- Language: auto-detect (or user-specified)

**Audio File Size Limits:**
- Whisper API max: 25MB per request
- M4A at 44.1kHz AAC mono high quality: ~1MB per 4 minutes
- Max single upload: ~100 minutes of audio
- For longer sessions: chunk audio into segments and merge transcripts

### 10.4 Summary Generation Prompt

```
You are a meeting notes assistant. Given the transcript of an in-person
conversation, generate:

1. **Key Points**: 3-7 bullet points summarizing the main topics discussed
2. **Decisions**: Any decisions or agreements reached
3. **Action Items**: Tasks mentioned with assignee (if stated) and deadline (if stated)
4. **Topics**: 2-5 topic tags for categorization

Rules:
- Be concise and specific; avoid vague language
- Use names when mentioned; otherwise use "Speaker"
- Only include action items that were explicitly discussed
- Match the language of the transcript

{if user_notes}
The user also took these inline notes during the conversation.
Enhance and expand these notes using context from the transcript,
maintaining the user's structure but adding detail and accuracy:

{user_notes}
{/if}

Transcript:
{transcript}
```

---

## 11. Privacy & Consent Framework

### 11.1 Design Principles

1. **Informed consent**: All participants should know recording is happening
2. **User control**: Easy start/stop; easy delete; no auto-recording
3. **Data minimization**: Only store what's needed; offer auto-delete policies
4. **Transparency**: Clear indicators during recording; accessible privacy controls

### 11.2 Consent Mechanisms

#### MVP: Manual Disclosure

- App displays reminder text before first capture: "Please ensure all participants consent to being recorded"
- User acknowledges with checkbox (stored in settings, shown once)
- Recording indicator visible on phone screen (required by iOS)

#### P1: Active Consent Features

| Feature | Implementation |
|---------|---------------|
| **Verbal consent prompt** | Play audio through glasses speakers: "This conversation will be recorded for note-taking purposes" |
| **Visual LED indicator** | Meta glasses have a recording LED; ensure it activates during capture (SDK-controlled) |
| **Consent card** | Show a simple card on phone screen that can be shown to participants |
| **Opt-out instruction** | "If anyone objects, tap here to cancel" during first 30 seconds |

### 11.3 Data Handling

| Data Type | Storage | Retention | Encryption |
|-----------|---------|-----------|------------|
| Raw audio | Local device only | User-controlled; suggest auto-delete after transcript | iOS file protection |
| Transcript | Local device only | Persistent until user deletes | iOS file protection |
| Summary | Local device only | Persistent until user deletes | iOS file protection |
| Audio sent to API | In-transit only | Not retained by OpenAI/Deepgram (per their policies) | TLS 1.3 |
| User notes | Local device only | Persistent until user deletes | iOS file protection |

### 11.4 Legal Considerations

| Jurisdiction | Requirement | App Behavior |
|-------------|-------------|--------------|
| **One-party consent** (38 US states, UK, etc.) | Only recorder needs to consent | Default behavior (user consents by starting) |
| **Two-party/all-party consent** (CA, FL, IL, etc.) | All participants must consent | Consent prompt feature (P1); user responsibility |
| **GDPR (EU)** | Legitimate interest or consent; right to deletion | Local-only storage; delete capability; no cloud sync |
| **Workplace recording** | Varies by employer policy | User responsibility; app provides tools, not legal advice |

**Disclaimer (shown in Settings):** "You are responsible for complying with local recording laws. This app provides tools to facilitate consent but cannot guarantee legal compliance in your jurisdiction."

---

## 12. Constraints & Limitations

### 12.1 Hardware Constraints

| Constraint | Spec | Impact | Mitigation |
|-----------|------|--------|------------|
| **Glasses battery** | Gen 2: 8hr general, 5hr continuous audio | Limits max capture duration | Show battery indicator; warn at 20% |
| **HFP audio quality** | 8-16 kHz via Bluetooth | Lower than direct mic; may affect transcription accuracy | Modern ASR handles this well; test and validate target >90% WER |
| **Single mic perspective** | Audio from wearer's position | Other speakers may be quieter; poor in noisy environments | Set expectations in UI; provide quiet environment tips |
| **Bluetooth range** | ~10m from phone | Phone must be nearby | Show connection status; alert if disconnected |
| **No on-glasses controls** | Can't start/stop from glasses (current SDK) | Must interact with phone to control | P2: voice trigger "Hey Meta, start capturing" |

### 12.2 Software Constraints

| Constraint | Details | Mitigation |
|-----------|---------|------------|
| **iOS background audio** | Requires `audio` background mode entitlement | Already using `.playAndRecord` category; add background mode |
| **Whisper API file limit** | 25MB per upload | Chunk audio for sessions >90 min |
| **Network required (MVP)** | No offline transcription | Queue for processing when online; P2 adds WhisperKit |
| **No real-time transcript (MVP)** | Batch processing only | Clear UX expectation; P1 adds streaming |
| **Storage space** | ~1MB per 4 min audio + transcript | Monitor storage; offer cleanup suggestions |

### 12.3 UX Constraints

| Constraint | Details | Mitigation |
|-----------|---------|------------|
| **Phone interaction required** | Must open app and tap to start/stop | Minimize taps; consider Siri shortcut |
| **No automatic start** | Can't detect "conversation started" reliably | P2: calendar integration for scheduled meetings |
| **Social friction** | Some people uncomfortable being recorded | Consent framework; option to record from device mic (more discrete) |
| **Note-taking during capture** | Typing on phone during conversation still breaks eye contact | Keep notes minimal; AI enhancement fills gaps |

---

## 13. Cost Analysis

### 13.1 Per-Conversation Costs

| Duration | Whisper API | GPT-4o-mini Summary | Total |
|----------|------------|-------------------|-------|
| 5 min | $0.03 | $0.002 | **$0.032** |
| 15 min | $0.09 | $0.003 | **$0.093** |
| 30 min | $0.18 | $0.005 | **$0.185** |
| 60 min | $0.36 | $0.008 | **$0.368** |
| 120 min | $0.72 | $0.012 | **$0.732** |

### 13.2 User Usage Scenarios

| User Type | Conversations/Day | Avg Duration | Daily Cost | Monthly Cost |
|-----------|-------------------|-------------|------------|-------------|
| Light (3/day) | 3 | 10 min | $0.19 | **$3.80** |
| Moderate (5/day) | 5 | 15 min | $0.47 | **$9.30** |
| Heavy (8/day) | 8 | 20 min | $1.00 | **$20.00** |
| Power (10/day) | 10 | 30 min | $1.85 | **$37.00** |

### 13.3 Comparison to Existing Voice Agent

| Mode | Cost/min | 1hr Cost | Use Case |
|------|---------|----------|----------|
| **Voice Agent** (Realtime API) | ~$0.60 | ~$36.00 | Interactive AI conversation |
| **Conversation Capture** (Whisper) | ~$0.006 | ~$0.37 | Passive recording + transcription |
| **Ratio** | **100x cheaper** | | |

### 13.4 Storage Requirements

| Duration | Audio (M4A) | Transcript (JSON) | Summary (JSON) | Total |
|----------|------------|-------------------|----------------|-------|
| 5 min | ~1.2 MB | ~5 KB | ~2 KB | ~1.2 MB |
| 30 min | ~7.5 MB | ~30 KB | ~3 KB | ~7.5 MB |
| 60 min | ~15 MB | ~60 KB | ~5 KB | ~15 MB |
| 1 month (moderate) | ~750 MB | ~3 MB | ~300 KB | ~750 MB |

**Recommendation:** Offer option to auto-delete audio files after successful transcription, retaining only the transcript and summary (~95% storage savings).

---

## 14. Phased Rollout Plan

### Phase 1: MVP (4-6 weeks)

**Goal:** Validate that HFP audio quality produces usable transcriptions

| Week | Deliverable |
|------|-------------|
| 1 | `ConversationCaptureManager` skeleton; state machine; audio recording integration |
| 2 | `ConversationCaptureView` UI; start/stop flow; timer and audio level display |
| 3 | Whisper API integration; batch transcription pipeline; transcript storage |
| 4 | GPT-4o-mini summary generation; thread integration; capture detail view |
| 5 | Testing, edge cases, error handling, audio quality validation |
| 6 | Polish, settings integration, onboarding flow |

**MVP Exit Criteria:**
- [ ] Can record a 30-minute conversation via glasses mic
- [ ] Transcription accuracy >85% WER in quiet environment
- [ ] Summary correctly identifies key points and action items
- [ ] Capture appears in Threads tab and is browseable
- [ ] Works with glasses disconnected (device mic fallback)
- [ ] No crashes during extended recording sessions

### Phase 2: Enhanced Experience (4-6 weeks)

**Goal:** Add real-time feedback and Granola-style note enhancement

| Week | Deliverable |
|------|-------------|
| 1-2 | Deepgram WebSocket integration for live transcription |
| 2-3 | Inline notes editor during capture |
| 3-4 | AI note enhancement (Granola-style: merge user notes + transcript) |
| 4-5 | Chat with transcript feature |
| 5-6 | Speaker labeling (you vs. other), consent prompt, photo snapshots |

### Phase 3: Intelligence Layer (6-8 weeks)

**Goal:** Cross-conversation insights and offline capability

| Deliverable |
|------------|
| WhisperKit on-device transcription (offline mode) |
| Full-text search across all transcripts |
| Cross-conversation topic analysis |
| Action item tracking across conversations |
| Export to Notion, email, other tools |
| Calendar integration for auto-start |

### Phase 4: Relationship Intelligence (8-12 weeks)

**Goal:** Transform from passive recorder to proactive relationship CRM

| Week | Deliverable |
|------|-------------|
| 1-2 | `PersonManager` singleton; `PersonProfile` data model and persistence; `PersonStore` for JSON storage |
| 2-3 | Face detection pipeline: Apple Vision `VNDetectFaceRectanglesRequest` → crop face from glasses photos |
| 3-4 | Face embedding: Core ML model (MobileFaceNet/ArcFace) for generating face vectors; cosine similarity matching |
| 4-5 | Integration with capture flow: "Snap Person" button during recording; auto-capture periodic face photos |
| 5-6 | AI extraction: GPT extracts person name, personal facts, commitments from transcript; links to PersonProfile |
| 6-7 | Relationship briefing: generate briefing card when known face recognized; show small talk suggestions + follow-ups |
| 7-8 | People directory UI: browseable list of all known people; person detail view with conversation timeline |
| 8-9 | Commitment tracking: dashboard of open commitments per person; mark as completed; reminder scheduling |
| 9-10 | Proactive prompts: pre-conversation briefing notifications; commitment reminders; reconnection suggestions |
| 10-12 | Knowledge graph: visual relationship map; cross-person topic analysis; Obsidian/CRM export |

**Phase 4 Exit Criteria:**
- [ ] Can capture photo of conversation partner during recording
- [ ] Face recognition correctly matches same person across encounters (>90% precision)
- [ ] AI correctly extracts names from transcripts (>80% accuracy when name is spoken)
- [ ] Relationship briefing surfaces relevant context within 3 seconds of face match
- [ ] Commitments are extracted and trackable per person
- [ ] All face data stays on-device (no cloud face recognition)

---

## 15. Success Metrics

### 15.1 Adoption Metrics

| Metric | Target (3 months) | Measurement |
|--------|-------------------|-------------|
| Users who try capture | 60% of active users | Analytics: first capture event |
| Weekly active capturers | 30% of active users | Analytics: 1+ capture/week |
| Captures per active user per week | 5+ | Analytics: capture count |
| Avg capture duration | 10-20 minutes | Analytics: session duration |

### 15.2 Quality Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Transcription accuracy (WER) | >85% (quiet), >75% (noisy) | Sample audit of transcripts |
| Summary usefulness | >4.0/5.0 rating | In-app feedback prompt |
| Action item accuracy | >80% correctly identified | Sample audit |
| User-reported "missed information" | <20% of captures | In-app feedback |

### 15.3 Engagement Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Transcript review rate | >50% of captures reviewed | Analytics: detail view opened |
| Chat with transcript usage (P1) | >30% of captures | Analytics: chat initiated |
| Note enhancement usage (P1) | >40% of captures with notes | Analytics: notes entered |
| Capture retention (not deleted) | >80% after 30 days | Analytics: deletion rate |

### 15.4 Relationship Intelligence Metrics (Phase 4)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Face recognition precision | >90% correct matches | Sample audit of matched profiles |
| Face recognition recall | >80% faces detected in capture photos | Face detection success rate |
| Name extraction accuracy | >80% when name is spoken in conversation | Audit extracted names vs. transcript |
| Commitment extraction recall | >70% of explicit commitments captured | Sample audit of transcripts |
| Briefing usefulness | >4.0/5.0 rating | In-app feedback after briefing shown |
| People profiles created | Avg 10+ per active user after 1 month | Analytics: profile count |
| Briefing engagement | >60% of briefings read (not dismissed) | Analytics: briefing interaction |
| Commitment completion rate | >50% of tracked commitments resolved | Analytics: status changes |

### 15.5 Business Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Feature-driven retention | +15% 30-day retention vs. baseline | Analytics: cohort analysis |
| API cost per user per month | <$15 (moderate user) | API usage tracking |
| App Store rating impact | Maintain 4.5+ | App Store reviews |

---

## 16. Open Questions & Risks

### 16.1 Open Questions

| # | Question | Impact | Owner | Decision Needed By |
|---|----------|--------|-------|-------------------|
| 1 | **HFP audio quality**: Is 8-16 kHz audio from glasses sufficient for >85% transcription accuracy? | P0 blocker: if quality is too low, core value prop fails | Engineering | Before MVP dev starts |
| 2 | **Tab vs. Mode**: Should Capture be a new tab or a mode within Voice Agent tab? | UX architecture; affects navigation and mental model | Design | Week 1 |
| 3 | **Audio retention**: Should we keep raw audio after transcription, or auto-delete to save storage? | Storage costs vs. re-transcription capability | Product | Week 3 |
| 4 | **Transcription provider**: Start with Whisper API (simpler, better accuracy) or Deepgram (streaming capable)? | Dev velocity vs. future flexibility | Engineering | Week 1 |
| 5 | **Thread integration**: Should captures be mixed into Threads tab or have their own dedicated list? | Information architecture; affects discoverability | Design | Week 1 |
| 6 | **Consent legal review**: Do we need legal counsel on recording consent UX? | Liability risk | Legal | Before public release |
| 7 | **Background recording**: How reliable is iOS background audio with HFP Bluetooth? | Core functionality: if it drops, capture is incomplete | Engineering | Week 2 |
| 8 | **Face embedding model**: Which Core ML model (MobileFaceNet vs ArcFace vs FaceNet) gives best accuracy/speed tradeoff on iOS? | Face recognition quality; model size ~10-50MB | Engineering | Phase 4 Week 1 |
| 9 | **Face matching threshold**: What cosine similarity threshold (0.5-0.8) minimizes false positives while maintaining recall? | Too low = wrong person matched; too high = doesn't recognize known faces | Engineering | Phase 4 Week 3 |
| 10 | **Biometric data regulations**: Do face embeddings constitute "biometric data" under BIPA (Illinois), GDPR Art. 9, or similar laws? | Legal compliance; may need additional consent for face data | Legal | Before Phase 4 launch |
| 11 | **Auto vs manual photo capture**: Should person photos be captured automatically (periodic) or only on user tap? | Privacy vs. convenience tradeoff; auto-capture more powerful but more intrusive | Design | Phase 4 Week 1 |
| 12 | **Export format**: If/when we add export, what format is most useful? CSV, markdown, Notion API? | Low priority — only needed if users request it | Product | Phase 4 (optional) |

### 16.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **HFP audio quality insufficient** | Medium | Critical | Early prototype test; fallback to device mic |
| **Bluetooth disconnection during capture** | Medium | High | Auto-switch to device mic; alert user; save partial recording |
| **Whisper API accuracy degraded with low-quality audio** | Low-Medium | High | Test with HFP-quality audio samples; compare providers |
| **Users don't remember to start capture** | High | Medium | P2: calendar integration, voice trigger, smart suggestions |
| **Privacy backlash / recording concerns** | Medium | High | Strong consent UX; transparent indicators; local-only storage |
| **iOS background audio restrictions** | Low | High | Test extensively; use proper background mode entitlement |
| **Storage bloat from audio files** | Medium | Medium | Auto-delete audio after transcription option; storage monitor |
| **API cost surprises for heavy users** | Low | Medium | Usage tracking in Settings; cost warnings at thresholds |
| **Meta SDK changes break audio capture** | Low | Medium | Abstract audio capture behind protocol; monitor SDK updates |
| **Face recognition false positives** | Medium | High | Conservative matching threshold; always show "Is this [name]?" confirmation |
| **Biometric privacy regulation** | Medium | High | All face data on-device only; no cloud processing; explicit opt-in; easy deletion |
| **Poor lighting / angle for face detection** | High | Medium | Graceful degradation — skip face match, still capture conversation; suggest re-snap |
| **Users find face recognition "creepy"** | Medium | Medium | Opt-in by default; clear explanation of on-device-only processing; no cloud faces |
| **Commitment extraction inaccuracy** | Medium | Medium | Always show extracted commitments for review; easy to dismiss false positives |

### 16.3 Recommended Pre-Development Validation

Before committing to full MVP development, run a **1-week spike** to answer the critical question:

> **"Is HFP Bluetooth audio from Meta Ray-Ban glasses good enough for accurate transcription?"**

**Spike Protocol:**
1. Record 10 conversations of varying lengths (5-30 min) in different environments (quiet office, coffee shop, outdoor walk)
2. Use both glasses HFP mic and device mic simultaneously for comparison
3. Transcribe both audio sources with Whisper API
4. Compare Word Error Rate (WER) between sources
5. Identify failure patterns (background noise, multiple speakers, distance)

**Go/No-Go Criteria:**
- WER <15% in quiet environment: **GO** for MVP
- WER 15-25% in quiet environment: **GO** with quality warnings in UX
- WER >25% in quiet environment: **PIVOT** to device-mic-first approach

---

## 17. Relationship Intelligence

### 17.1 Vision

> **Every person you meet becomes a node in your professional memory. Every conversation adds context. Your glasses remember what you forget.**

Relationship Intelligence transforms Conversation Capture from a passive recorder into an active relationship partner. The glasses camera identifies who you're talking to, the AI extracts what matters, and the system proactively surfaces the right context at the right time — before you need to ask.

This is the feature that no competitor can replicate: **only smart glasses can simultaneously see who you're talking to AND hear what you're discussing**, creating a complete relationship record tied to a real face.

### 17.2 The Problem This Solves

**The "Who Was That?" Problem:**
- You meet 5-10 people per day. By next week, you've forgotten half the details.
- "They mentioned their kid plays soccer... or was that someone else?"
- "I promised to send them something... what was it?"
- "They said they'd introduce me to someone... did that happen?"

**The "Awkward Re-Introduction" Problem:**
- You've met this person before but can't remember their name or context
- You repeat questions they've already answered
- You forget to follow up on things they care about
- You miss opportunities for meaningful connection

**The "Dropped Follow-Up" Problem:**
- You made a commitment in conversation but it's not in your task manager
- They promised you something but there's no record to check
- Important relationship maintenance falls through the cracks

### 17.3 How It Works

#### Step 1: Capture (During Conversation)

During an active capture session, the user can snap a photo of the person they're talking to:

- **Manual**: Tap "Snap Person" button in the recording UI
- **Semi-automatic** (P2): App prompts "Capture a photo of who you're talking to?" at start of recording
- Photos are captured via existing `GlassesManager.capturePhotoAsync()` pipeline

The photo is processed entirely on-device:
1. Apple Vision framework detects face bounding box
2. Face is cropped and normalized
3. Core ML model generates a 128-dimensional face embedding vector
4. Embedding is compared against stored person embeddings

#### Step 2: Identify (Post-Conversation)

After capture ends, the AI processing pipeline adds a new stage:

```
stopCapture() → transcribe → generate title → generate summary
                                                      │
                                                      ▼
                                              extract relationship data
                                              ┌─────────────────────┐
                                              │ • Person name (from  │
                                              │   transcript)        │
                                              │ • Personal facts     │
                                              │ • Commitments made   │
                                              │ • Topics discussed   │
                                              └─────────────────────┘
                                                      │
                                                      ▼
                                              link to PersonProfile
                                              (create new or update existing)
```

**AI Extraction Prompt (appended to summary generation):**

```
Additionally, extract the following relationship intelligence:

1. **People mentioned**: Names of people in the conversation (the user's conversation
   partner and anyone else referenced). For each person, note their role/organization
   if mentioned.

2. **Personal facts**: Things the conversation partner shared about their personal life
   (family, hobbies, upcoming plans, preferences). These will be used for future
   small talk.

3. **Commitments**:
   - Things the user promised to do for the other person
   - Things the other person promised to do for the user
   - Mutual commitments (meetings, follow-ups)
   Include deadlines if mentioned.

Return as JSON:
{
  "people": [{"name": "...", "role": "...", "organization": "..."}],
  "personalFacts": [{"about": "person name", "fact": "...", "category": "family|work|interests|plans"}],
  "commitments": [{"description": "...", "direction": "youToThem|themToYou|mutual", "deadline": "..."}]
}
```

#### Step 3: Recognize (Next Encounter)

When the user starts a new capture and snaps a photo:

1. Face embedding is generated from the new photo
2. Cosine similarity is computed against all stored person embeddings
3. If similarity > threshold (0.65): **match found**
4. Relationship briefing is generated and displayed

The briefing appears as a card at the top of the recording UI:

```
┌───────────────────────────────────────────┐
│ 👤 Sarah Chen recognized                  │
│ Last: Feb 26 · "Q1 Planning Discussion"   │
│                                            │
│ 💬 Ask about: Skiing trip to Tahoe        │
│ ⚠️ You owe: Send mockup feedback          │
│ 📥 Ask for: Intro to their CTO            │
│                                            │
│ [View Full Profile]         [Dismiss]      │
└───────────────────────────────────────────┘
```

#### Step 4: Evolve (Over Time)

Each conversation enriches the person's profile:
- New personal facts are appended (deduplicated by AI)
- Commitments are tracked (pending → completed)
- Topic history builds a picture of what you discuss with this person
- Interaction frequency and recency are tracked

The system becomes proactively helpful:
- **Before a meeting**: If you have a calendar event with someone in your People directory, generate a pre-meeting briefing
- **Stale relationships**: "You haven't talked to Mike in 3 weeks — last discussed the Q2 launch"
- **Overdue commitments**: "You promised Sarah the feedback 5 days ago"

### 17.4 Privacy Architecture

Relationship Intelligence handles sensitive biometric data. The privacy architecture is designed to be defensible:

| Principle | Implementation |
|-----------|---------------|
| **All face data on-device** | Face embeddings are never sent to any cloud service. Only transcript text goes to OpenAI for extraction. |
| **Explicit opt-in** | Face recognition is OFF by default. User must enable it in Settings with clear explanation. |
| **Easy deletion** | Any person profile can be deleted instantly, removing all face data, facts, and commitments. |
| **No background face scanning** | Face matching only happens when user actively takes a "Snap Person" photo during capture. No passive surveillance. |
| **Transparent matching** | Always shows "Is this [name]?" confirmation. User can correct or dismiss. |
| **Biometric data handling** | Face embeddings stored in iOS-encrypted app sandbox. No export of raw biometric vectors. |

**BIPA/GDPR Considerations:**
- Illinois BIPA: Requires written consent before collecting biometric identifiers. App shows explicit consent dialog before enabling face recognition.
- GDPR Art. 9: Biometric data is "special category." Processed under explicit consent basis. Right to erasure fully supported.
- The system is designed so face data NEVER leaves the device, minimizing regulatory surface area.

### 17.5 Cost Analysis (Relationship Intelligence)

| Component | Cost | Notes |
|-----------|------|-------|
| Face detection (Apple Vision) | Free | On-device framework |
| Face embedding (Core ML) | Free | On-device model (~10MB) |
| Face matching (cosine similarity) | Free | Local computation |
| Relationship extraction (GPT) | ~$0.003/capture | Appended to existing summary prompt |
| Briefing generation (GPT) | ~$0.002/briefing | Short context, fast model |
| **Total per capture** | **~$0.005** additional | On top of existing transcription + summary costs |

The relationship intelligence layer adds minimal cost because:
1. Face recognition is entirely on-device (free)
2. Relationship data extraction is appended to the existing summary generation prompt (marginal token increase)
3. Briefing generation only happens when a known face is matched (not every capture)

### 17.6 Technical Implementation Files

| New File | Purpose |
|----------|---------|
| `PersonManager.swift` | Singleton managing person profiles, face recognition pipeline, and briefing generation |
| `PersonProfile.swift` | Data models for PersonProfile, PersonalFact, Commitment, RelationshipBriefing |
| `FaceRecognitionEngine.swift` | Apple Vision face detection + Core ML face embedding + cosine similarity matching |
| `PersonStore.swift` | JSON persistence for people_index.json and per-person data |
| `PeopleView.swift` | SwiftUI view for People directory (list of all known people) |
| `PersonDetailView.swift` | SwiftUI view for individual person profile with conversation timeline |
| `RelationshipBriefingView.swift` | SwiftUI card view shown during capture when known face recognized |
| `CommitmentDashboardView.swift` | SwiftUI view for tracking open commitments across all people |

| Modified File | Changes |
|---------------|---------|
| `ConversationCaptureManager.swift` | Add "Snap Person" photo capture during recording; add relationship extraction to post-capture pipeline |
| `ConversationCaptureView.swift` | Add "Snap Person" button in recording UI; show relationship briefing card |
| `CaptureDetailView.swift` | Show linked person profiles; display extracted commitments |
| `CaptureModels.swift` | Add `personIds` and `commitmentIds` to CaptureSession |
| `ContentView.swift` | Add People tab (or integrate into existing navigation) |
| `SettingsView.swift` | Add Relationship Intelligence settings section (enable/disable, manage face data) |

---

## Appendix A: Glossary

| Term | Definition |
|------|-----------|
| **HFP** | Hands-Free Profile; Bluetooth protocol for mono audio (used by glasses mic) |
| **VAD** | Voice Activity Detection; automatic detection of speech vs. silence |
| **WER** | Word Error Rate; standard measure of transcription accuracy (lower = better) |
| **Diarization** | Identifying and labeling different speakers in audio |
| **Barge-in** | User interrupting the AI while it's speaking |
| **WhisperKit** | Apple-optimized on-device implementation of OpenAI's Whisper model |
| **PCM16** | Pulse Code Modulation, 16-bit signed integer audio format |
| **M4A** | MPEG-4 Audio container format (used for AAC-encoded audio) |
| **Face Embedding** | A numerical vector (128-512 dimensions) representing unique facial features; used for matching faces across photos |
| **ArcFace/MobileFaceNet** | Neural network architectures for face recognition, optimized for mobile; generates face embeddings from cropped face images |
| **Cosine Similarity** | Mathematical measure of similarity between two vectors (0.0 = no match, 1.0 = identical); used for face matching |
| **BIPA** | Biometric Information Privacy Act (Illinois); regulates collection and storage of biometric identifiers including facial geometry |
| **Knowledge Graph** | Network of entities (people, topics, conversations) connected by relationships; enables cross-entity queries and insights |

## Appendix B: Competitive Feature Matrix

| Feature | This App (MVP) | This App (P1) | This App (P2) | Granola | Otter.ai | Limitless |
|---------|---------------|---------------|---------------|---------|----------|-----------|
| In-person recording | Yes | Yes | Yes | Workaround | No | Yes |
| Virtual meeting | No | No | No | Yes | Yes | Yes |
| Real-time transcript | No | Yes | Yes | Yes | Yes | Yes |
| Inline notes | No | Yes | Yes | Yes | No | No |
| Note enhancement | No | Yes | Yes | Yes | No | No |
| Chat with transcript | No | Yes | Yes | Yes | Yes | Yes |
| Speaker diarization | No | Basic | Advanced | Basic | Advanced | Basic |
| Visual capture (camera) | No | Yes | Yes | No | No | No |
| Offline transcription | No | No | Yes | No | No | Yes |
| Cross-conversation search | No | No | Yes | Yes | Yes | Yes |
| Wearable form factor | Yes | Yes | Yes | No | No | Yes |
| AI assistant integration | Yes | Yes | Yes | No | No | Yes |
| Memory system | Yes | Yes | Yes | No | No | No |
| **Face recognition** | No | **Yes** | **Yes** | No | No | No |
| **Person profiles/CRM** | No | **Yes** | **Yes** | No | No | No |
| **Relationship briefings** | No | **Yes** | **Yes** | No | No | No |
| **Commitment tracking** | No | No | **Yes** | No | No | No |
| **Knowledge graph** | No | No | **Optional** | No | No | No |

## Appendix C: References

- [Granola.ai](https://www.granola.ai/) - AI notepad for meetings
- [Granola raises $43M at $250M valuation](https://techcrunch.com/2025/05/14/ai-note-taking-app-granola-raises-43m-at-250m-valuation-launches-collaborative-features/) - TechCrunch, May 2025
- [Granola in-person meeting workarounds](https://circleback.ai/how-to/recording-in-person-meetings-with-granola-workarounds) - Circleback
- [Granola Review](https://tldv.io/blog/granola-review/) - tl;dv, 2026
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - On-device speech recognition for Apple Silicon
- [Deepgram Pricing](https://deepgram.com/pricing) - Streaming transcription pricing
- [Deepgram Streaming API](https://developers.deepgram.com/reference/speech-to-text/listen-streaming) - WebSocket documentation
- [Ray-Ban Meta Gen 2 Specs](https://about.fb.com/news/2025/09/ray-ban-meta-gen-2-better-battery-life-video-capture/) - Meta, September 2025
- [Meta Ray-Ban Battery Life](https://www.meta.com/help/ai-glasses/303057485648146/) - Meta Help Center
- [Speech-to-Text API Pricing Comparison](https://deepgram.com/learn/speech-to-text-api-pricing-breakdown-2025) - Deepgram, 2025
