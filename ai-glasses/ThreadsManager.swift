//
//  ThreadsManager.swift
//  ai-glasses
//
//  Manages conversation thread persistence and history
//

import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ai-glasses", category: "ThreadsManager")

// MARK: - Data Models

struct StoredMessage: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let isUser: Bool
    let text: String
    let timestamp: Date
    
    init(id: UUID, isUser: Bool, text: String, timestamp: Date) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
    }
    
    /// Create from ChatMessage
    init(from chatMessage: ChatMessage) {
        self.id = chatMessage.id
        self.isUser = chatMessage.isUser
        self.text = chatMessage.text
        self.timestamp = chatMessage.timestamp
    }
}

struct ConversationThread: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var title: String
    var messages: [StoredMessage]
    
    init(id: UUID, createdAt: Date, updatedAt: Date, title: String, messages: [StoredMessage]) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.messages = messages
    }
    
    /// Create a new empty thread
    static func create() -> ConversationThread {
        let now = Date()
        return ConversationThread(
            id: UUID(),
            createdAt: now,
            updatedAt: now,
            title: Self.generateDefaultTitle(date: now),
            messages: []
        )
    }
    
    /// Generate default title from date
    static func generateDefaultTitle(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Generate title from first user message
    mutating func generateTitleFromFirstMessage() {
        guard let firstUserMessage = messages.first(where: { $0.isUser }) else { return }
        
        // Take first 50 characters of the message
        let text = firstUserMessage.text
        if text.count <= 50 {
            title = text
        } else {
            let index = text.index(text.startIndex, offsetBy: 47)
            title = String(text[..<index]) + "..."
        }
    }
}

// MARK: - Threads Manager

@MainActor
final class ThreadsManager: ObservableObject {
    static let shared = ThreadsManager()
    
    @Published private(set) var threads: [ConversationThread] = []
    @Published private(set) var activeThreadId: UUID?
    
    /// Thread ID to continue when VoiceAgent appears (set by ThreadDetailView)
    @Published var pendingContinuationThreadId: UUID?
    
    private let fileName = "threads.json"
    
    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    private init() {
        load()
    }
    
    // MARK: - Thread Management
    
    /// Create a new thread and set it as active
    func createThread() -> UUID {
        let thread = ConversationThread.create()
        threads.insert(thread, at: 0) // Add to beginning (newest first)
        activeThreadId = thread.id
        save()
        logger.info("📝 Created new thread: \(thread.id)")
        return thread.id
    }
    
    /// Save messages to the active thread
    func saveMessages(messages: [ChatMessage]) {
        guard let threadId = activeThreadId,
              let index = threads.firstIndex(where: { $0.id == threadId }) else {
            logger.warning("⚠️ No active thread to save messages to")
            return
        }
        
        // Convert ChatMessages to StoredMessages
        let storedMessages = messages.map { StoredMessage(from: $0) }
        
        threads[index].messages = storedMessages
        threads[index].updatedAt = Date()
        
        // Update title if this is first save with messages
        if threads[index].messages.count > 0 && threads[index].title == ConversationThread.generateDefaultTitle(date: threads[index].createdAt) {
            threads[index].generateTitleFromFirstMessage()
        }
        
        save()
        logger.info("💾 Saved \(storedMessages.count) messages to thread \(threadId)")
    }
    
    /// Finalize the active thread (called on disconnect)
    func finalizeActiveThread() {
        guard let threadId = activeThreadId,
              let index = threads.firstIndex(where: { $0.id == threadId }) else {
            return
        }
        
        // If thread has no messages, delete it
        if threads[index].messages.isEmpty {
            threads.remove(at: index)
            logger.info("🗑️ Deleted empty thread: \(threadId)")
        } else {
            // Make sure title is generated from content
            threads[index].generateTitleFromFirstMessage()
            threads[index].updatedAt = Date()
            logger.info("✅ Finalized thread: \(threadId) with \(self.threads[index].messages.count) messages")
        }
        
        activeThreadId = nil
        save()
    }
    
    /// Delete a thread by ID
    func deleteThread(id: UUID) {
        threads.removeAll { $0.id == id }
        if activeThreadId == id {
            activeThreadId = nil
        }
        save()
        logger.info("🗑️ Deleted thread: \(id)")
    }
    
    /// Get thread by ID
    func thread(id: UUID) -> ConversationThread? {
        threads.first { $0.id == id }
    }
    
    /// Resume an existing thread (set it as active for continuation)
    func resumeThread(id: UUID) -> [StoredMessage]? {
        guard let thread = thread(id: id) else {
            logger.warning("⚠️ Cannot resume thread: not found \(id)")
            return nil
        }
        
        activeThreadId = id
        logger.info("▶️ Resumed thread: \(id) with \(thread.messages.count) messages")
        return thread.messages
    }
    
    // MARK: - Persistence
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.info("Threads file does not exist, starting fresh")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            threads = try decoder.decode([ConversationThread].self, from: data)
            // Sort by updatedAt descending (newest first)
            threads.sort { $0.updatedAt > $1.updatedAt }
            logger.info("Loaded \(self.threads.count) threads")
        } catch {
            logger.error("❌ Failed to load threads: \(error)")
            // Print full error details to console for debugging
            print("❌ ThreadsManager load error: \(error)")
        }
    }
    
    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(threads)
            try data.write(to: fileURL, options: .atomic)
            logger.debug("Saved threads to \(self.fileURL.path)")
        } catch {
            logger.error("❌ Failed to save threads: \(error)")
            print("❌ ThreadsManager save error: \(error)")
        }
    }
}
