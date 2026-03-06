//
//  CaptureModelsTests.swift
//  meta-glasses-ios-openaiTests
//
//  Tests for Conversation Capture data models and persistence
//

import Testing
import Foundation
@testable import meta_glasses_ios_openai

// MARK: - CaptureSession Tests

struct CaptureSessionTests {

    @Test func defaultInitialization() {
        let session = CaptureSession()

        #expect(session.duration == 0)
        #expect(session.transcriptStatus == .pending)
        #expect(session.summaryStatus == .pending)
        #expect(session.audioSource == .deviceMic)
        #expect(session.wordCount == 0)
        #expect(session.location == nil)
        #expect(session.title == "")
    }

    @Test func codableRoundTrip() throws {
        let session = CaptureSession(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            title: "Test Capture",
            duration: 300,
            audioFilePath: "captures/test/audio.m4a",
            transcriptStatus: .completed,
            summaryStatus: .inProgress,
            audioSource: .glasses,
            wordCount: 1234,
            location: "San Francisco, CA"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CaptureSession.self, from: data)

        #expect(decoded.id == session.id)
        #expect(decoded.title == "Test Capture")
        #expect(decoded.duration == 300)
        #expect(decoded.transcriptStatus == .completed)
        #expect(decoded.summaryStatus == .inProgress)
        #expect(decoded.audioSource == .glasses)
        #expect(decoded.wordCount == 1234)
        #expect(decoded.location == "San Francisco, CA")
    }

    @Test func defaultTitle() {
        let date = Date()
        let title = CaptureSession.defaultTitle(date: date)
        #expect(title.hasPrefix("Capture"))
    }

    @Test func equatable() {
        let id = UUID()
        let date = Date()
        let a = CaptureSession(id: id, createdAt: date, updatedAt: date, title: "Test")
        let b = CaptureSession(id: id, createdAt: date, updatedAt: date, title: "Test")
        #expect(a == b)
    }
}

// MARK: - Enum Tests

struct CaptureEnumTests {

    @Test func transcriptStatusCodable() throws {
        for status in [TranscriptStatus.pending, .inProgress, .completed, .failed] {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TranscriptStatus.self, from: data)
            #expect(decoded == status)
        }
    }

    @Test func summaryStatusCodable() throws {
        for status in [SummaryStatus.pending, .inProgress, .completed, .failed] {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(SummaryStatus.self, from: data)
            #expect(decoded == status)
        }
    }

    @Test func audioSourceDisplayName() {
        #expect(AudioSource.glasses.displayName == "Meta Glasses")
        #expect(AudioSource.deviceMic.displayName == "Device Microphone")
    }

    @Test func audioSourceCodable() throws {
        for source in [AudioSource.glasses, .deviceMic] {
            let data = try JSONEncoder().encode(source)
            let decoded = try JSONDecoder().decode(AudioSource.self, from: data)
            #expect(decoded == source)
        }
    }

    @Test func captureStateEquatable() {
        #expect(CaptureState.idle == CaptureState.idle)
        #expect(CaptureState.recording == CaptureState.recording)
        #expect(CaptureState.processing == CaptureState.processing)
        #expect(CaptureState.completed == CaptureState.completed)
        #expect(CaptureState.error("test") == CaptureState.error("test"))
        #expect(CaptureState.error("a") != CaptureState.error("b"))
        #expect(CaptureState.idle != CaptureState.recording)
    }

    @Test func speakerLabelCodable() throws {
        for label in [SpeakerLabel.user, .other, .unknown] {
            let data = try JSONEncoder().encode(label)
            let decoded = try JSONDecoder().decode(SpeakerLabel.self, from: data)
            #expect(decoded == label)
        }
    }
}

// MARK: - Transcript Tests

struct TranscriptTests {

    @Test func codableRoundTrip() throws {
        let captureId = UUID()
        let transcript = Transcript(
            captureId: captureId,
            segments: [
                TranscriptSegment(startTime: 0, endTime: 5.5, text: "Hello world", speaker: .user, confidence: 0.95),
                TranscriptSegment(startTime: 5.5, endTime: 10, text: "Hi there", speaker: .other, confidence: 0.88)
            ],
            fullText: "Hello world Hi there",
            language: "en",
            provider: "whisper"
        )

        let data = try JSONEncoder().encode(transcript)
        let decoded = try JSONDecoder().decode(Transcript.self, from: data)

        #expect(decoded.captureId == captureId)
        #expect(decoded.segments.count == 2)
        #expect(decoded.fullText == "Hello world Hi there")
        #expect(decoded.language == "en")
        #expect(decoded.provider == "whisper")
        #expect(decoded.segments[0].text == "Hello world")
        #expect(decoded.segments[0].speaker == .user)
        #expect(decoded.segments[0].confidence == 0.95)
        #expect(decoded.segments[1].startTime == 5.5)
    }

    @Test func segmentWithNilFields() throws {
        let segment = TranscriptSegment(startTime: 0, endTime: 5, text: "test", speaker: nil, confidence: nil)
        let data = try JSONEncoder().encode(segment)
        let decoded = try JSONDecoder().decode(TranscriptSegment.self, from: data)
        #expect(decoded.speaker == nil)
        #expect(decoded.confidence == nil)
    }
}

// MARK: - CaptureSummary Tests

struct CaptureSummaryTests {

    @Test func codableRoundTrip() throws {
        let captureId = UUID()
        let summary = CaptureSummary(
            captureId: captureId,
            keyPoints: ["Budget approved at $50K", "Launch by March 15"],
            decisions: ["Go with option A"],
            actionItems: [
                ActionItem(description: "Send follow-up email", assignee: "John", deadline: "March 1"),
                ActionItem(description: "Set up staging", assignee: nil, deadline: nil, isCompleted: true)
            ],
            sentiment: "constructive",
            topics: ["budget", "timeline", "launch"]
        )

        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(CaptureSummary.self, from: data)

        #expect(decoded.captureId == captureId)
        #expect(decoded.keyPoints.count == 2)
        #expect(decoded.decisions == ["Go with option A"])
        #expect(decoded.actionItems.count == 2)
        #expect(decoded.actionItems[0].assignee == "John")
        #expect(decoded.actionItems[1].isCompleted == true)
        #expect(decoded.sentiment == "constructive")
        #expect(decoded.topics.count == 3)
    }

    @Test func actionItemDefaults() {
        let item = ActionItem(description: "Do the thing")
        #expect(item.assignee == nil)
        #expect(item.deadline == nil)
        #expect(item.isCompleted == false)
    }
}

// MARK: - ThreadType Migration Tests

struct ThreadTypeMigrationTests {

    @Test func decodesLegacyThreadWithoutType() throws {
        // Simulate legacy JSON without threadType and captureId
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-01T01:00:00Z",
            "title": "Old Thread",
            "messages": []
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let thread = try decoder.decode(ConversationThread.self, from: json)

        #expect(thread.threadType == .voiceAgent)
        #expect(thread.captureId == nil)
        #expect(thread.title == "Old Thread")
    }

    @Test func decodesCaptureThread() throws {
        let captureId = UUID()
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-01T01:00:00Z",
            "title": "Capture Thread",
            "messages": [],
            "threadType": "capture",
            "captureId": "\(captureId.uuidString)"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let thread = try decoder.decode(ConversationThread.self, from: json)

        #expect(thread.threadType == .capture)
        #expect(thread.captureId == captureId)
    }

    @Test func threadTypeCodable() throws {
        for t in [ThreadType.voiceAgent, .capture] {
            let data = try JSONEncoder().encode(t)
            let decoded = try JSONDecoder().decode(ThreadType.self, from: data)
            #expect(decoded == t)
        }
    }
}

// MARK: - Settings Migration Tests

struct CaptureSettingsMigrationTests {

    @Test func decodesSettingsWithoutCaptureFields() throws {
        let json = """
        {
            "userPrompt": "Be helpful",
            "memories": {},
            "openAIAPIKey": "sk-test",
            "perplexityAPIKey": "",
            "geminiAPIKey": ""
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        #expect(settings.captureAutoSummary == true)
        #expect(settings.captureConsentAcknowledged == false)
        #expect(settings.userPrompt == "Be helpful")
    }

    @Test func decodesSettingsWithCaptureFields() throws {
        let json = """
        {
            "userPrompt": "",
            "memories": {},
            "openAIAPIKey": "",
            "perplexityAPIKey": "",
            "geminiAPIKey": "",
            "captureAutoSummary": false,
            "captureConsentAcknowledged": true
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        #expect(settings.captureAutoSummary == false)
        #expect(settings.captureConsentAcknowledged == true)
    }
}

// MARK: - WhisperAPIClient Tests

struct WhisperAPIResponseTests {

    @Test func parsesVerboseResponse() throws {
        let json = """
        {
            "text": "Hello world, this is a test.",
            "language": "en",
            "duration": 5.5,
            "segments": [
                {"id": 0, "start": 0.0, "end": 2.5, "text": "Hello world,"},
                {"id": 1, "start": 2.5, "end": 5.5, "text": "this is a test."}
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WhisperVerboseResponse.self, from: json)

        #expect(response.text == "Hello world, this is a test.")
        #expect(response.language == "en")
        #expect(response.duration == 5.5)
        #expect(response.segments?.count == 2)
        #expect(response.segments?[0].start == 0.0)
        #expect(response.segments?[0].end == 2.5)
        #expect(response.segments?[1].text == "this is a test.")
    }

    @Test func parsesResponseWithoutSegments() throws {
        let json = """
        {
            "text": "Hello world",
            "language": "en"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(WhisperVerboseResponse.self, from: json)

        #expect(response.text == "Hello world")
        #expect(response.segments == nil)
        #expect(response.duration == nil)
    }
}

// MARK: - CaptureStore Tests

struct CaptureStoreTests {

    @Test @MainActor func storeIsSingleton() {
        let store1 = CaptureStore.shared
        let store2 = CaptureStore.shared
        #expect(store1 === store2)
    }

    @Test @MainActor func saveAndRetrieveSession() {
        let store = CaptureStore.shared
        let session = CaptureSession(
            id: UUID(),
            title: "Test Save Session",
            duration: 120,
            audioSource: .deviceMic
        )

        store.save(session)

        let retrieved = store.session(for: session.id)
        #expect(retrieved != nil)
        #expect(retrieved?.title == "Test Save Session")
        #expect(retrieved?.duration == 120)

        // Cleanup
        store.delete(id: session.id)
    }

    @Test @MainActor func deleteSession() {
        let store = CaptureStore.shared
        let session = CaptureSession(id: UUID(), title: "To Delete")

        store.save(session)
        #expect(store.session(for: session.id) != nil)

        store.delete(id: session.id)
        #expect(store.session(for: session.id) == nil)
    }

    @Test @MainActor func saveAndLoadTranscript() {
        let store = CaptureStore.shared
        let captureId = UUID()

        let transcript = Transcript(
            captureId: captureId,
            segments: [
                TranscriptSegment(startTime: 0, endTime: 5, text: "Test segment", speaker: nil, confidence: nil)
            ],
            fullText: "Test segment",
            language: "en",
            provider: "whisper"
        )

        store.saveTranscript(transcript, for: captureId)
        let loaded = store.loadTranscript(for: captureId)

        #expect(loaded != nil)
        #expect(loaded?.fullText == "Test segment")
        #expect(loaded?.segments.count == 1)

        // Cleanup
        store.delete(id: captureId)
    }

    @Test @MainActor func saveAndLoadSummary() {
        let store = CaptureStore.shared
        let captureId = UUID()

        let summary = CaptureSummary(
            captureId: captureId,
            keyPoints: ["Point 1", "Point 2"],
            decisions: ["Decision 1"],
            actionItems: [ActionItem(description: "Do thing", assignee: "Alice")],
            sentiment: "positive",
            topics: ["topic1"]
        )

        store.saveSummary(summary, for: captureId)
        let loaded = store.loadSummary(for: captureId)

        #expect(loaded != nil)
        #expect(loaded?.keyPoints.count == 2)
        #expect(loaded?.actionItems.count == 1)
        #expect(loaded?.actionItems.first?.assignee == "Alice")

        // Cleanup
        store.delete(id: captureId)
    }

    @Test @MainActor func loadTranscriptForNonexistentCapture() {
        let store = CaptureStore.shared
        let result = store.loadTranscript(for: UUID())
        #expect(result == nil)
    }

    @Test @MainActor func loadSummaryForNonexistentCapture() {
        let store = CaptureStore.shared
        let result = store.loadSummary(for: UUID())
        #expect(result == nil)
    }

    @Test @MainActor func sessionsAreSortedByDate() {
        let store = CaptureStore.shared
        let older = CaptureSession(
            id: UUID(),
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-3600),
            title: "Older"
        )
        let newer = CaptureSession(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            title: "Newer"
        )

        store.save(older)
        store.save(newer)

        let sessions = store.loadAll()
        if sessions.count >= 2 {
            let olderIndex = sessions.firstIndex(where: { $0.id == older.id })
            let newerIndex = sessions.firstIndex(where: { $0.id == newer.id })
            if let oi = olderIndex, let ni = newerIndex {
                #expect(ni < oi) // newer should come first
            }
        }

        // Cleanup
        store.delete(id: older.id)
        store.delete(id: newer.id)
    }
}

// MARK: - ConversationCaptureManager Tests

struct CaptureManagerTests {

    @Test @MainActor func managerIsSingleton() {
        let m1 = ConversationCaptureManager.shared
        let m2 = ConversationCaptureManager.shared
        #expect(m1 === m2)
    }

    @Test @MainActor func initialStateIsIdle() {
        let manager = ConversationCaptureManager.shared
        #expect(manager.captureState == .idle)
        #expect(manager.elapsedTime == 0)
        #expect(manager.audioLevel == 0)
        #expect(manager.currentSession == nil)
    }

    @Test @MainActor func resetToIdle() {
        let manager = ConversationCaptureManager.shared
        manager.resetToIdle()

        #expect(manager.captureState == .idle)
        #expect(manager.elapsedTime == 0)
        #expect(manager.audioLevel == 0)
        #expect(manager.currentSession == nil)
        #expect(manager.processingStep == "")
    }
}
