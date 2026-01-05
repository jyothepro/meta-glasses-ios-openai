//
//  SettingsManager.swift
//  meta-glasses-ios-openai
//
//  Created by AI Assistant on 04/01/2026.
//

import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta-glasses-ios-openai", category: "SettingsManager")

// MARK: - Settings Data Model

struct AppSettings: Codable {
    var userPrompt: String
    var memories: [String: String]
    var openAIAPIKey: String
    var perplexityAPIKey: String
    
    static let empty = AppSettings(
        userPrompt: "",
        memories: [:],
        openAIAPIKey: Config.openAIAPIKey,
        perplexityAPIKey: Config.perplexityAPIKey
    )
    
    /// Custom decoder to handle missing fields during migration
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userPrompt = try container.decodeIfPresent(String.self, forKey: .userPrompt) ?? ""
        memories = try container.decodeIfPresent([String: String].self, forKey: .memories) ?? [:]
        // Use Config values as defaults for new fields (migration support)
        openAIAPIKey = try container.decodeIfPresent(String.self, forKey: .openAIAPIKey) ?? Config.openAIAPIKey
        perplexityAPIKey = try container.decodeIfPresent(String.self, forKey: .perplexityAPIKey) ?? Config.perplexityAPIKey
    }
    
    init(userPrompt: String, memories: [String: String], openAIAPIKey: String, perplexityAPIKey: String) {
        self.userPrompt = userPrompt
        self.memories = memories
        self.openAIAPIKey = openAIAPIKey
        self.perplexityAPIKey = perplexityAPIKey
    }
}

// MARK: - Settings Manager

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published private(set) var settings: AppSettings = .empty
    
    private let fileName = "settings.json"
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.5
    
    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    private init() {
        load()
    }
    
    // MARK: - Public Properties
    
    var userPrompt: String {
        get { settings.userPrompt }
        set {
            settings.userPrompt = newValue
            scheduleSave()
        }
    }
    
    var memories: [String: String] {
        settings.memories
    }
    
    var openAIAPIKey: String {
        get { settings.openAIAPIKey }
        set {
            settings.openAIAPIKey = newValue
            scheduleSave()
        }
    }
    
    var perplexityAPIKey: String {
        get { settings.perplexityAPIKey }
        set {
            settings.perplexityAPIKey = newValue
            scheduleSave()
        }
    }
    
    // MARK: - API Key Status
    
    var isOpenAIConfigured: Bool {
        !settings.openAIAPIKey.isEmpty
    }
    
    var isPerplexityConfigured: Bool {
        !settings.perplexityAPIKey.isEmpty
    }
    
    /// Returns 1 if OpenAI API key is not configured, otherwise 0
    var missingAPIKeysCount: Int {
        isOpenAIConfigured ? 0 : 1
    }
    
    // MARK: - Memory Management
    
    /// Manage memory: add if key doesn't exist, update if exists, delete if value is empty
    func manageMemory(key: String, value: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedKey.isEmpty else {
            logger.warning("Attempted to manage memory with empty key")
            return
        }
        
        if trimmedValue.isEmpty {
            // Delete
            if settings.memories.removeValue(forKey: trimmedKey) != nil {
                logger.info("Deleted memory: \(trimmedKey)")
            } else {
                logger.info("Memory key not found for deletion: \(trimmedKey)")
            }
        } else if settings.memories[trimmedKey] != nil {
            // Update
            settings.memories[trimmedKey] = trimmedValue
            logger.info("Updated memory: \(trimmedKey)")
        } else {
            // Add
            settings.memories[trimmedKey] = trimmedValue
            logger.info("Added memory: \(trimmedKey)")
        }
        
        scheduleSave()
    }
    
    /// Update memory directly (for UI editing)
    func updateMemory(oldKey: String, newKey: String, value: String) {
        let trimmedOldKey = oldKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNewKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedNewKey.isEmpty else {
            logger.warning("Attempted to update memory with empty new key")
            return
        }
        
        // Remove old key if it changed
        if trimmedOldKey != trimmedNewKey {
            settings.memories.removeValue(forKey: trimmedOldKey)
        }
        
        settings.memories[trimmedNewKey] = trimmedValue
        saveNow()
    }
    
    /// Delete memory by key
    func deleteMemory(key: String) {
        settings.memories.removeValue(forKey: key)
        saveNow()
    }
    
    /// Add new empty memory
    func addEmptyMemory() -> String {
        var newKey = "new_memory"
        var counter = 1
        while settings.memories[newKey] != nil {
            newKey = "new_memory_\(counter)"
            counter += 1
        }
        settings.memories[newKey] = ""
        saveNow()
        return newKey
    }
    
    // MARK: - Persistence
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.info("Settings file does not exist, using defaults")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            settings = try JSONDecoder().decode(AppSettings.self, from: data)
            logger.info("Loaded settings: \(self.settings.memories.count) memories")
        } catch {
            logger.error("Failed to load settings: \(error.localizedDescription)")
        }
    }
    
    /// Schedule a debounced save - will only write to disk after saveDebounceInterval of inactivity
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.performSave()
            }
        }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }
    
    /// Immediately save to disk (use on view disappear, app background)
    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        performSave()
    }
    
    private func performSave() {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: fileURL, options: .atomic)
            logger.info("Saved settings to \(self.fileURL.path)")
        } catch {
            logger.error("Failed to save settings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Instructions Generation
    
    /// Generate instructions section for memories and user prompt
    func generateInstructionsAddendum() -> String {
        var addendum = ""
        
        // Add memories section if any exist
        if !settings.memories.isEmpty {
            addendum += "\n\n# User Memories\n"
            for (key, value) in settings.memories.sorted(by: { $0.key < $1.key }) {
                addendum += "- \(key): \(value)\n"
            }
        }
        
        // Add user prompt if not empty
        let trimmedPrompt = settings.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrompt.isEmpty {
            addendum += "\n\n# User Additional Instructions\n\(trimmedPrompt)"
        }
        
        return addendum
    }
}
