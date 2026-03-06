//
//  CaptureModels.swift
//  meta-glasses-ios-openai
//
//  Data models and persistence for Conversation Capture feature
//

import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta-glasses-ios-openai", category: "CaptureModels")

// MARK: - Enums

enum CaptureState: Equatable {
    case idle
    case recording
    case processing
    case completed
    case error(String)
}

enum TranscriptStatus: String, Codable, Equatable {
    case pending
    case inProgress
    case completed
    case failed
}

enum SummaryStatus: String, Codable, Equatable {
    case pending
    case inProgress
    case completed
    case failed
}

enum AudioSource: String, Codable, Equatable {
    case glasses
    case deviceMic

    var displayName: String {
        switch self {
        case .glasses: return "Meta Glasses"
        case .deviceMic: return "Device Microphone"
        }
    }
}

enum SpeakerLabel: String, Codable, Equatable {
    case user
    case other
    case unknown
}

// MARK: - Core Models

struct CaptureSession: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var title: String
    var duration: TimeInterval
    var audioFilePath: String
    var transcriptStatus: TranscriptStatus
    var summaryStatus: SummaryStatus
    var audioSource: AudioSource
    var wordCount: Int
    var location: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        title: String = "",
        duration: TimeInterval = 0,
        audioFilePath: String = "",
        transcriptStatus: TranscriptStatus = .pending,
        summaryStatus: SummaryStatus = .pending,
        audioSource: AudioSource = .deviceMic,
        wordCount: Int = 0,
        location: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.duration = duration
        self.audioFilePath = audioFilePath
        self.transcriptStatus = transcriptStatus
        self.summaryStatus = summaryStatus
        self.audioSource = audioSource
        self.wordCount = wordCount
        self.location = location
    }

    /// Generate default title from date
    static func defaultTitle(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Capture \(formatter.string(from: date))"
    }
}

struct TranscriptSegment: Codable, Equatable, Identifiable {
    var id: UUID { UUID() }
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let speaker: SpeakerLabel?
    let confidence: Float?

    // Custom Equatable — ignore generated id
    static func == (lhs: TranscriptSegment, rhs: TranscriptSegment) -> Bool {
        lhs.startTime == rhs.startTime &&
        lhs.endTime == rhs.endTime &&
        lhs.text == rhs.text &&
        lhs.speaker == rhs.speaker &&
        lhs.confidence == rhs.confidence
    }

    private enum CodingKeys: String, CodingKey {
        case startTime, endTime, text, speaker, confidence
    }
}

struct Transcript: Codable, Equatable {
    let captureId: UUID
    let segments: [TranscriptSegment]
    let fullText: String
    let language: String
    let provider: String
}

struct ActionItem: Codable, Equatable, Identifiable {
    let id: UUID
    let description: String
    let assignee: String?
    let deadline: String?
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        description: String,
        assignee: String? = nil,
        deadline: String? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.description = description
        self.assignee = assignee
        self.deadline = deadline
        self.isCompleted = isCompleted
    }
}

struct CaptureSummary: Codable, Equatable {
    let captureId: UUID
    let keyPoints: [String]
    let decisions: [String]
    let actionItems: [ActionItem]
    let sentiment: String?
    let topics: [String]
}

// MARK: - CaptureStore

@MainActor
final class CaptureStore: ObservableObject {
    static let shared = CaptureStore()

    @Published private(set) var sessions: [CaptureSession] = []

    private let indexFileName = "captures_index.json"
    private let capturesDirName = "captures"

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var capturesDirectory: URL {
        documentsDirectory.appendingPathComponent(capturesDirName)
    }

    private var indexFileURL: URL {
        documentsDirectory.appendingPathComponent(indexFileName)
    }

    private init() {
        ensureCapturesDirectory()
        load()
    }

    // MARK: - Directory Setup

    private func ensureCapturesDirectory() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: capturesDirectory.path) {
            do {
                try fm.createDirectory(at: capturesDirectory, withIntermediateDirectories: true)
                logger.info("Created captures directory")
            } catch {
                logger.error("Failed to create captures directory: \(error.localizedDescription)")
            }
        }
    }

    /// Get or create the directory for a specific capture
    func captureDirectory(for captureId: UUID) -> URL {
        let dir = capturesDirectory.appendingPathComponent(captureId.uuidString)
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create capture directory: \(error.localizedDescription)")
            }
        }
        return dir
    }

    /// Audio file path for a capture
    func audioFileURL(for captureId: UUID) -> URL {
        captureDirectory(for: captureId).appendingPathComponent("audio.m4a")
    }

    // MARK: - Session CRUD

    func save(_ session: CaptureSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        persistIndex()
        logger.info("Saved capture session: \(session.id)")
    }

    func loadAll() -> [CaptureSession] {
        return sessions
    }

    func session(for id: UUID) -> CaptureSession? {
        sessions.first { $0.id == id }
    }

    func delete(id: UUID) {
        sessions.removeAll { $0.id == id }

        // Remove capture directory and all files
        let dir = capturesDirectory.appendingPathComponent(id.uuidString)
        do {
            if FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.removeItem(at: dir)
            }
        } catch {
            logger.error("Failed to delete capture directory: \(error.localizedDescription)")
        }

        persistIndex()
        logger.info("Deleted capture: \(id)")
    }

    // MARK: - Transcript Persistence

    func saveTranscript(_ transcript: Transcript, for captureId: UUID) {
        let url = captureDirectory(for: captureId).appendingPathComponent("transcript.json")
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(transcript)
            try data.write(to: url, options: .atomic)
            logger.info("Saved transcript for capture: \(captureId)")
        } catch {
            logger.error("Failed to save transcript: \(error.localizedDescription)")
        }
    }

    func loadTranscript(for captureId: UUID) -> Transcript? {
        let url = captureDirectory(for: captureId).appendingPathComponent("transcript.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Transcript.self, from: data)
        } catch {
            logger.error("Failed to load transcript: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Summary Persistence

    func saveSummary(_ summary: CaptureSummary, for captureId: UUID) {
        let url = captureDirectory(for: captureId).appendingPathComponent("summary.json")
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(summary)
            try data.write(to: url, options: .atomic)
            logger.info("Saved summary for capture: \(captureId)")
        } catch {
            logger.error("Failed to save summary: \(error.localizedDescription)")
        }
    }

    func loadSummary(for captureId: UUID) -> CaptureSummary? {
        let url = captureDirectory(for: captureId).appendingPathComponent("summary.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CaptureSummary.self, from: data)
        } catch {
            logger.error("Failed to load summary: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Index Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: indexFileURL.path) else {
            logger.info("Captures index does not exist, starting fresh")
            return
        }

        do {
            let data = try Data(contentsOf: indexFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            sessions = try decoder.decode([CaptureSession].self, from: data)
            sessions.sort { $0.updatedAt > $1.updatedAt }
            logger.info("Loaded \(self.sessions.count) capture sessions")
        } catch {
            logger.error("Failed to load captures index: \(error.localizedDescription)")
        }
    }

    private func persistIndex() {
        sessions.sort { $0.updatedAt > $1.updatedAt }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sessions)
            try data.write(to: indexFileURL, options: .atomic)
            logger.debug("Saved captures index")
        } catch {
            logger.error("Failed to save captures index: \(error.localizedDescription)")
        }
    }
}
