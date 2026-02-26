//
//  APIDebugLoggerTests.swift
//  meta-glasses-ios-openaiTests
//
//  Tests for API debug logging functionality
//

import Testing
import Foundation
@testable import meta_glasses_ios_openai

// MARK: - API Service Tests

struct APIServiceTests {

    @Test func allServicesHaveIcons() {
        for service in APIService.allCases {
            #expect(!service.icon.isEmpty, "Service \(service.rawValue) should have an icon")
        }
    }

    @Test func allServicesHaveColors() {
        for service in APIService.allCases {
            #expect(!service.color.isEmpty, "Service \(service.rawValue) should have a color")
        }
    }

    @Test func serviceRawValues() {
        #expect(APIService.openAIRealtime.rawValue == "OpenAI Realtime")
        #expect(APIService.openAIChat.rawValue == "OpenAI Chat")
        #expect(APIService.openAIVision.rawValue == "OpenAI Vision")
        #expect(APIService.perplexity.rawValue == "Perplexity")
        #expect(APIService.geminiLive.rawValue == "Gemini Live")
    }

    @Test func serviceCaseCount() {
        #expect(APIService.allCases.count == 5)
    }

    @Test func geminiLiveServiceProperties() {
        let service = APIService.geminiLive

        #expect(service.icon == "video")
        #expect(service.color == "red")
    }
}

// MARK: - API Log Entry Tests

struct APILogEntryTests {

    @Test func entryInitialization() {
        let entry = APILogEntry(
            service: .openAIChat,
            endpoint: "chat/completions",
            method: "POST",
            requestSummary: "Test prompt",
            responseSummary: "Test response",
            statusCode: 200,
            durationMs: 150,
            error: nil,
            requestImages: [],
            responseImages: [],
            isWebSocket: false
        )

        #expect(entry.service == .openAIChat)
        #expect(entry.endpoint == "chat/completions")
        #expect(entry.method == "POST")
        #expect(entry.requestSummary == "Test prompt")
        #expect(entry.responseSummary == "Test response")
        #expect(entry.statusCode == 200)
        #expect(entry.durationMs == 150)
        #expect(entry.error == nil)
        #expect(!entry.isWebSocket)
    }

    @Test func entryIsSuccessFor200() {
        let entry = APILogEntry(
            service: .openAIChat,
            endpoint: "test",
            requestSummary: "test",
            statusCode: 200
        )

        #expect(entry.isSuccess)
    }

    @Test func entryIsSuccessFor201() {
        let entry = APILogEntry(
            service: .openAIChat,
            endpoint: "test",
            requestSummary: "test",
            statusCode: 201
        )

        #expect(entry.isSuccess)
    }

    @Test func entryIsNotSuccessFor400() {
        let entry = APILogEntry(
            service: .openAIChat,
            endpoint: "test",
            requestSummary: "test",
            statusCode: 400
        )

        #expect(!entry.isSuccess)
    }

    @Test func entryIsNotSuccessFor500() {
        let entry = APILogEntry(
            service: .openAIChat,
            endpoint: "test",
            requestSummary: "test",
            statusCode: 500
        )

        #expect(!entry.isSuccess)
    }

    @Test func entryIsNotSuccessWithError() {
        let entry = APILogEntry(
            service: .openAIChat,
            endpoint: "test",
            requestSummary: "test",
            error: "Connection failed"
        )

        #expect(!entry.isSuccess)
    }

    @Test func entryIsSuccessWithNoStatusCodeAndNoError() {
        let entry = APILogEntry(
            service: .openAIRealtime,
            endpoint: "websocket",
            requestSummary: "test",
            isWebSocket: true
        )

        #expect(entry.isSuccess)
    }

    @Test func formattedTimestamp() {
        let entry = APILogEntry(
            service: .openAIChat,
            endpoint: "test",
            requestSummary: "test"
        )

        let formatted = entry.formattedTimestamp
        #expect(!formatted.isEmpty)
        #expect(formatted.contains(":")) // Should be in HH:mm:ss format
    }

    @Test func formattedDurationMilliseconds() {
        let entry = APILogEntry(
            service: .openAIChat,
            endpoint: "test",
            requestSummary: "test",
            durationMs: 500
        )

        #expect(entry.formattedDuration == "500ms")
    }

    @Test func formattedDurationSeconds() {
        let entry = APILogEntry(
            service: .openAIChat,
            endpoint: "test",
            requestSummary: "test",
            durationMs: 1500
        )

        #expect(entry.formattedDuration == "1.5s")
    }

    @Test func formattedDurationNil() {
        let entry = APILogEntry(
            service: .openAIChat,
            endpoint: "test",
            requestSummary: "test",
            durationMs: nil
        )

        #expect(entry.formattedDuration == nil)
    }

    @Test func entryHasUniqueId() {
        let entry1 = APILogEntry(
            service: .openAIChat,
            endpoint: "test",
            requestSummary: "test"
        )

        let entry2 = APILogEntry(
            service: .openAIChat,
            endpoint: "test",
            requestSummary: "test"
        )

        #expect(entry1.id != entry2.id)
    }

    @Test func webSocketEntry() {
        let entry = APILogEntry(
            service: .geminiLive,
            endpoint: "realtime_input",
            method: "→",
            requestSummary: "Video frame",
            isWebSocket: true
        )

        #expect(entry.isWebSocket)
        #expect(entry.method == "→")
    }
}

// MARK: - API Debug Logger Tests

struct APIDebugLoggerTests {

    @Test @MainActor func loggerIsSingleton() {
        let logger1 = APIDebugLogger.shared
        let logger2 = APIDebugLogger.shared

        #expect(logger1 === logger2)
    }

    @Test @MainActor func loggerDefaultSettings() {
        let logger = APIDebugLogger.shared

        #expect(logger.isEnabled == true)
        #expect(logger.maxEntries == 100)
    }

    @Test @MainActor func logEntryAddsToList() {
        let logger = APIDebugLogger.shared
        let initialCount = logger.entries.count

        let entry = APILogEntry(
            service: .openAIChat,
            endpoint: "test",
            requestSummary: "test entry"
        )

        logger.log(entry)

        #expect(logger.entries.count == initialCount + 1)
    }

    @Test @MainActor func logEntryIsLIFO() {
        let logger = APIDebugLogger.shared

        let entry1 = APILogEntry(
            service: .openAIChat,
            endpoint: "first",
            requestSummary: "first entry"
        )

        let entry2 = APILogEntry(
            service: .openAIChat,
            endpoint: "second",
            requestSummary: "second entry"
        )

        logger.log(entry1)
        logger.log(entry2)

        // Most recent entry should be first (LIFO)
        #expect(logger.entries.first?.endpoint == "second")
    }

    @Test @MainActor func clearRemovesAllEntries() {
        let logger = APIDebugLogger.shared

        // Add some entries
        logger.log(APILogEntry(service: .openAIChat, endpoint: "test", requestSummary: "test"))

        // Clear
        logger.clear()

        #expect(logger.entries.isEmpty)
    }

    @Test @MainActor func filterByService() {
        let logger = APIDebugLogger.shared
        logger.clear()

        // Add entries for different services
        logger.log(APILogEntry(service: .openAIChat, endpoint: "chat", requestSummary: "chat"))
        logger.log(APILogEntry(service: .geminiLive, endpoint: "gemini", requestSummary: "gemini"))
        logger.log(APILogEntry(service: .openAIChat, endpoint: "chat2", requestSummary: "chat2"))

        let chatEntries = logger.entries(for: .openAIChat)
        let geminiEntries = logger.entries(for: .geminiLive)

        #expect(chatEntries.count == 2)
        #expect(geminiEntries.count == 1)
    }

    @Test @MainActor func filterErrorEntries() {
        let logger = APIDebugLogger.shared
        logger.clear()

        // Add success and error entries
        logger.log(APILogEntry(service: .openAIChat, endpoint: "success", requestSummary: "test", statusCode: 200))
        logger.log(APILogEntry(service: .openAIChat, endpoint: "error", requestSummary: "test", statusCode: 500))
        logger.log(APILogEntry(service: .openAIChat, endpoint: "error2", requestSummary: "test", error: "Failed"))

        let errors = logger.errorEntries()

        #expect(errors.count == 2)
    }

    @Test @MainActor func disabledLoggerDoesNotLog() {
        let logger = APIDebugLogger.shared
        logger.clear()
        logger.isEnabled = false

        logger.log(APILogEntry(service: .openAIChat, endpoint: "test", requestSummary: "test"))

        #expect(logger.entries.isEmpty)

        // Re-enable for other tests
        logger.isEnabled = true
    }

    @Test @MainActor func exportAsJSON() {
        let logger = APIDebugLogger.shared
        logger.clear()

        logger.log(APILogEntry(
            service: .openAIChat,
            endpoint: "test",
            requestSummary: "test request",
            responseSummary: "test response",
            statusCode: 200,
            durationMs: 100
        ))

        let json = logger.exportAsJSON()

        #expect(json != nil)
        #expect(json?.contains("openAIChat") == true || json?.contains("OpenAI Chat") == true)
        #expect(json?.contains("test request") == true)
    }

    @Test @MainActor func logChatCompletion() {
        let logger = APIDebugLogger.shared
        logger.clear()

        logger.logChatCompletion(
            model: "gpt-4o-mini",
            prompt: "Hello",
            response: "Hi there!",
            statusCode: 200,
            durationMs: 150
        )

        #expect(logger.entries.count == 1)
        #expect(logger.entries.first?.service == .openAIChat)
        #expect(logger.entries.first?.endpoint.contains("gpt-4o-mini") == true)
    }

    @Test @MainActor func logVisionCall() {
        let logger = APIDebugLogger.shared
        logger.clear()

        let imageData = Data([0x00, 0x01, 0x02])

        logger.logVisionCall(
            prompt: "What's in this image?",
            imageData: imageData,
            response: "I see a cat",
            statusCode: 200,
            durationMs: 500
        )

        #expect(logger.entries.count == 1)
        #expect(logger.entries.first?.service == .openAIVision)
        #expect(logger.entries.first?.requestImages.count == 1)
    }

    @Test @MainActor func logPerplexitySearch() {
        let logger = APIDebugLogger.shared
        logger.clear()

        logger.logPerplexitySearch(
            query: "Bitcoin price",
            response: "$50,000",
            statusCode: 200,
            durationMs: 300
        )

        #expect(logger.entries.count == 1)
        #expect(logger.entries.first?.service == .perplexity)
        #expect(logger.entries.first?.requestSummary.contains("Bitcoin") == true)
    }

    @Test @MainActor func logGeminiLiveEvent() {
        let logger = APIDebugLogger.shared
        logger.clear()

        logger.logGeminiLiveEvent(
            eventType: "connect",
            direction: "send",
            summary: "Connected to Gemini"
        )

        #expect(logger.entries.count == 1)
        #expect(logger.entries.first?.service == .geminiLive)
        #expect(logger.entries.first?.isWebSocket == true)
    }

    @Test @MainActor func logGeminiLiveFrameSent() {
        let logger = APIDebugLogger.shared
        logger.clear()

        let imageData = Data([0xFF, 0xD8, 0xFF]) // JPEG header

        logger.logGeminiLiveFrameSent(imageData: imageData)

        #expect(logger.entries.count == 1)
        #expect(logger.entries.first?.service == .geminiLive)
        #expect(logger.entries.first?.requestImages.count == 1)
    }

    @Test @MainActor func logGeminiLiveAudioReceived() {
        let logger = APIDebugLogger.shared
        logger.clear()

        logger.logGeminiLiveAudioReceived(audioBytes: 4096)

        #expect(logger.entries.count == 1)
        #expect(logger.entries.first?.service == .geminiLive)
        #expect(logger.entries.first?.responseSummary?.contains("4096") == true)
    }

    @Test @MainActor func logGeminiLiveTextReceived() {
        let logger = APIDebugLogger.shared
        logger.clear()

        logger.logGeminiLiveTextReceived(text: "Great form!")

        #expect(logger.entries.count == 1)
        #expect(logger.entries.first?.service == .geminiLive)
        #expect(logger.entries.first?.responseSummary == "Great form!")
    }

    @Test @MainActor func logRealtimeImageSent() {
        let logger = APIDebugLogger.shared
        logger.clear()

        let imageData = Data([0xFF, 0xD8, 0xFF])

        logger.logRealtimeImageSent(imageData: imageData)

        #expect(logger.entries.count == 1)
        #expect(logger.entries.first?.service == .openAIRealtime)
        #expect(logger.entries.first?.requestImages.count == 1)
    }
}

// MARK: - Max Entries Limit Tests

struct APIDebugLoggerLimitTests {

    @Test @MainActor func entriesLimitedToMaxEntries() {
        let logger = APIDebugLogger.shared
        logger.clear()

        let maxEntries = logger.maxEntries

        // Add more than max entries
        for i in 0..<(maxEntries + 50) {
            logger.log(APILogEntry(
                service: .openAIChat,
                endpoint: "entry_\(i)",
                requestSummary: "Entry \(i)"
            ))
        }

        #expect(logger.entries.count <= maxEntries)
    }

    @Test @MainActor func oldestEntriesRemovedFirst() {
        let logger = APIDebugLogger.shared
        logger.clear()

        // Set a small max for testing
        let originalMax = logger.maxEntries
        logger.maxEntries = 5

        // Add 10 entries
        for i in 0..<10 {
            logger.log(APILogEntry(
                service: .openAIChat,
                endpoint: "entry_\(i)",
                requestSummary: "Entry \(i)"
            ))
        }

        // Should have only 5 entries (the newest ones)
        #expect(logger.entries.count == 5)

        // The most recent (entry_9) should be first
        #expect(logger.entries.first?.endpoint == "entry_9")

        // The oldest kept (entry_5) should be last
        #expect(logger.entries.last?.endpoint == "entry_5")

        // Restore original max
        logger.maxEntries = originalMax
        logger.clear()
    }
}
