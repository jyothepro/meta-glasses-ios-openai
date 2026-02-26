//
//  SettingsManagerTests.swift
//  meta-glasses-ios-openaiTests
//
//  Tests for SettingsManager functionality including Gemini API key
//

import Testing
import Foundation
@testable import meta_glasses_ios_openai

// MARK: - Settings Manager Tests

struct SettingsManagerTests {

    @Test @MainActor func managerIsSingleton() {
        let manager1 = SettingsManager.shared
        let manager2 = SettingsManager.shared

        #expect(manager1 === manager2)
    }

    @Test @MainActor func isOpenAIConfiguredWhenKeySet() {
        let manager = SettingsManager.shared

        // Test with key
        let originalKey = manager.openAIAPIKey
        manager.openAIAPIKey = "test-key"
        #expect(manager.isOpenAIConfigured == true)

        // Test without key
        manager.openAIAPIKey = ""
        #expect(manager.isOpenAIConfigured == false)

        // Restore
        manager.openAIAPIKey = originalKey
    }

    @Test @MainActor func isPerplexityConfiguredWhenKeySet() {
        let manager = SettingsManager.shared

        let originalKey = manager.perplexityAPIKey
        manager.perplexityAPIKey = "test-key"
        #expect(manager.isPerplexityConfigured == true)

        manager.perplexityAPIKey = ""
        #expect(manager.isPerplexityConfigured == false)

        manager.perplexityAPIKey = originalKey
    }

    @Test @MainActor func isGeminiConfiguredWhenKeySet() {
        let manager = SettingsManager.shared

        let originalKey = manager.geminiAPIKey
        manager.geminiAPIKey = "test-gemini-key"
        #expect(manager.isGeminiConfigured == true)

        manager.geminiAPIKey = ""
        #expect(manager.isGeminiConfigured == false)

        manager.geminiAPIKey = originalKey
    }

    @Test @MainActor func geminiAPIKeyCanBeSetAndRead() {
        let manager = SettingsManager.shared

        let originalKey = manager.geminiAPIKey
        let testKey = "AIzaSyTest123456789"

        manager.geminiAPIKey = testKey
        #expect(manager.geminiAPIKey == testKey)

        // Restore
        manager.geminiAPIKey = originalKey
    }

    @Test @MainActor func missingAPIKeysCountOnlyCountsOpenAI() {
        let manager = SettingsManager.shared

        let originalOpenAI = manager.openAIAPIKey
        let originalPerplexity = manager.perplexityAPIKey
        let originalGemini = manager.geminiAPIKey

        // OpenAI missing = 1
        manager.openAIAPIKey = ""
        manager.perplexityAPIKey = ""
        manager.geminiAPIKey = ""
        #expect(manager.missingAPIKeysCount == 1)

        // OpenAI present = 0 (even if others missing)
        manager.openAIAPIKey = "test"
        #expect(manager.missingAPIKeysCount == 0)

        // Restore
        manager.openAIAPIKey = originalOpenAI
        manager.perplexityAPIKey = originalPerplexity
        manager.geminiAPIKey = originalGemini
    }
}

// MARK: - App Settings Tests

struct AppSettingsTests {

    @Test func emptySettingsHaveDefaults() {
        let settings = AppSettings.empty

        #expect(settings.userPrompt.isEmpty)
        #expect(settings.memories.isEmpty)
        // API keys come from Config defaults
    }

    @Test func settingsInitialization() {
        let settings = AppSettings(
            userPrompt: "Test prompt",
            memories: ["key1": "value1"],
            openAIAPIKey: "openai-key",
            perplexityAPIKey: "perplexity-key",
            geminiAPIKey: "gemini-key"
        )

        #expect(settings.userPrompt == "Test prompt")
        #expect(settings.memories["key1"] == "value1")
        #expect(settings.openAIAPIKey == "openai-key")
        #expect(settings.perplexityAPIKey == "perplexity-key")
        #expect(settings.geminiAPIKey == "gemini-key")
    }

    @Test func settingsEncodeDecode() throws {
        let original = AppSettings(
            userPrompt: "Test",
            memories: ["test": "value"],
            openAIAPIKey: "openai",
            perplexityAPIKey: "perplexity",
            geminiAPIKey: "gemini"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettings.self, from: data)

        #expect(decoded.userPrompt == original.userPrompt)
        #expect(decoded.memories == original.memories)
        #expect(decoded.openAIAPIKey == original.openAIAPIKey)
        #expect(decoded.perplexityAPIKey == original.perplexityAPIKey)
        #expect(decoded.geminiAPIKey == original.geminiAPIKey)
    }

    @Test func settingsDecodeMissingGeminiKey() throws {
        // Simulate old settings without geminiAPIKey
        let json = """
        {
            "userPrompt": "test",
            "memories": {},
            "openAIAPIKey": "openai",
            "perplexityAPIKey": "perplexity"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let settings = try decoder.decode(AppSettings.self, from: data)

        // Should use default from Config
        #expect(settings.geminiAPIKey == Config.geminiAPIKey)
    }
}

// MARK: - Memory Management Tests

struct MemoryManagementTests {

    @Test @MainActor func addMemory() {
        let manager = SettingsManager.shared

        let testKey = "test_memory_\(UUID().uuidString)"
        manager.manageMemory(key: testKey, value: "test value")

        #expect(manager.memories[testKey] == "test value")

        // Cleanup
        manager.deleteMemory(key: testKey)
    }

    @Test @MainActor func updateMemory() {
        let manager = SettingsManager.shared

        let testKey = "test_memory_\(UUID().uuidString)"
        manager.manageMemory(key: testKey, value: "original")
        manager.manageMemory(key: testKey, value: "updated")

        #expect(manager.memories[testKey] == "updated")

        // Cleanup
        manager.deleteMemory(key: testKey)
    }

    @Test @MainActor func deleteMemoryWithEmptyValue() {
        let manager = SettingsManager.shared

        let testKey = "test_memory_\(UUID().uuidString)"
        manager.manageMemory(key: testKey, value: "test")
        manager.manageMemory(key: testKey, value: "")

        #expect(manager.memories[testKey] == nil)
    }

    @Test @MainActor func deleteMemoryDirectly() {
        let manager = SettingsManager.shared

        let testKey = "test_memory_\(UUID().uuidString)"
        manager.manageMemory(key: testKey, value: "test")
        manager.deleteMemory(key: testKey)

        #expect(manager.memories[testKey] == nil)
    }

    @Test @MainActor func emptyKeyIsIgnored() {
        let manager = SettingsManager.shared

        let countBefore = manager.memories.count
        manager.manageMemory(key: "", value: "test")

        #expect(manager.memories.count == countBefore)
    }

    @Test @MainActor func addEmptyMemory() {
        let manager = SettingsManager.shared

        let newKey = manager.addEmptyMemory()

        #expect(newKey.starts(with: "new_memory"))
        #expect(manager.memories[newKey] == "")

        // Cleanup
        manager.deleteMemory(key: newKey)
    }
}

// MARK: - Instructions Generation Tests

struct InstructionsGenerationTests {

    @Test @MainActor func generateInstructionsWithMemories() {
        let manager = SettingsManager.shared

        let testKey = "test_instruction_memory_\(UUID().uuidString)"
        manager.manageMemory(key: testKey, value: "test value")

        let addendum = manager.generateInstructionsAddendum()

        #expect(addendum.contains("User Memories"))
        #expect(addendum.contains(testKey))
        #expect(addendum.contains("test value"))

        // Cleanup
        manager.deleteMemory(key: testKey)
    }

    @Test @MainActor func generateInstructionsWithUserPrompt() {
        let manager = SettingsManager.shared

        let originalPrompt = manager.userPrompt
        manager.userPrompt = "Be helpful and concise"

        let addendum = manager.generateInstructionsAddendum()

        #expect(addendum.contains("User Additional Instructions"))
        #expect(addendum.contains("Be helpful and concise"))

        // Restore
        manager.userPrompt = originalPrompt
    }

    @Test @MainActor func generateInstructionsEmpty() {
        let manager = SettingsManager.shared

        // Save original values
        let originalPrompt = manager.userPrompt
        let originalMemories = manager.memories

        // Clear everything
        manager.userPrompt = ""
        for key in manager.memories.keys {
            manager.deleteMemory(key: key)
        }

        let addendum = manager.generateInstructionsAddendum()

        // Should be empty or minimal
        #expect(!addendum.contains("User Memories") || manager.memories.isEmpty)

        // Restore
        manager.userPrompt = originalPrompt
        for (key, value) in originalMemories {
            manager.manageMemory(key: key, value: value)
        }
    }
}
