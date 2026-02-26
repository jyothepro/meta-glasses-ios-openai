//
//  APIDebugLogger.swift
//  meta-glasses-ios-openai
//
//  Debug logging for all AI API calls - captures requests, responses, and images
//

import Foundation
import UIKit
import Combine
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta-glasses-ios-openai", category: "APIDebugLogger")

// MARK: - API Log Entry

struct APILogEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let service: APIService
    let endpoint: String
    let method: String
    let requestSummary: String
    let responseSummary: String?
    let statusCode: Int?
    let durationMs: Int?
    let error: String?
    let requestImages: [Data]  // Base64 decoded image data
    let responseImages: [Data]
    let isWebSocket: Bool

    init(
        service: APIService,
        endpoint: String,
        method: String = "POST",
        requestSummary: String,
        responseSummary: String? = nil,
        statusCode: Int? = nil,
        durationMs: Int? = nil,
        error: String? = nil,
        requestImages: [Data] = [],
        responseImages: [Data] = [],
        isWebSocket: Bool = false
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.service = service
        self.endpoint = endpoint
        self.method = method
        self.requestSummary = requestSummary
        self.responseSummary = responseSummary
        self.statusCode = statusCode
        self.durationMs = durationMs
        self.error = error
        self.requestImages = requestImages
        self.responseImages = responseImages
        self.isWebSocket = isWebSocket
    }

    var isSuccess: Bool {
        if let code = statusCode {
            return code >= 200 && code < 300
        }
        return error == nil
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    var formattedDuration: String? {
        guard let ms = durationMs else { return nil }
        if ms < 1000 {
            return "\(ms)ms"
        } else {
            return String(format: "%.1fs", Double(ms) / 1000.0)
        }
    }
}

// MARK: - API Service Types

enum APIService: String, CaseIterable {
    case openAIRealtime = "OpenAI Realtime"
    case openAIChat = "OpenAI Chat"
    case openAIVision = "OpenAI Vision"
    case perplexity = "Perplexity"
    case geminiLive = "Gemini Live"

    var icon: String {
        switch self {
        case .openAIRealtime: return "waveform"
        case .openAIChat: return "bubble.left.and.bubble.right"
        case .openAIVision: return "eye"
        case .perplexity: return "magnifyingglass"
        case .geminiLive: return "video"
        }
    }

    var color: String {
        switch self {
        case .openAIRealtime: return "purple"
        case .openAIChat: return "green"
        case .openAIVision: return "blue"
        case .perplexity: return "orange"
        case .geminiLive: return "red"
        }
    }
}

// MARK: - API Debug Logger

@MainActor
final class APIDebugLogger: ObservableObject {

    // MARK: - Singleton

    static let shared = APIDebugLogger()

    // MARK: - Published State

    @Published private(set) var entries: [APILogEntry] = []
    @Published var isEnabled: Bool = true
    @Published var maxEntries: Int = 100

    // MARK: - Private Properties

    private let queue = DispatchQueue(label: "com.meta-glasses.api-logger", qos: .utility)

    // MARK: - Initialization

    private init() {
        logger.info("APIDebugLogger initialized")
    }

    // MARK: - Public Methods

    /// Log an API call
    func log(_ entry: APILogEntry) {
        guard isEnabled else { return }

        entries.insert(entry, at: 0)

        // Trim old entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        // Log to console as well
        let status = entry.isSuccess ? "✅" : "❌"
        let duration = entry.formattedDuration ?? "?"
        logger.info("\(status) [\(entry.service.rawValue)] \(entry.endpoint) - \(duration)")
    }

    /// Log an HTTP API call with timing
    func logHTTPCall(
        service: APIService,
        endpoint: String,
        requestSummary: String,
        requestImages: [Data] = [],
        startTime: Date,
        response: HTTPURLResponse?,
        responseBody: String?,
        responseImages: [Data] = [],
        error: Error? = nil
    ) {
        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

        let entry = APILogEntry(
            service: service,
            endpoint: endpoint,
            method: "POST",
            requestSummary: requestSummary,
            responseSummary: responseBody,
            statusCode: response?.statusCode,
            durationMs: durationMs,
            error: error?.localizedDescription,
            requestImages: requestImages,
            responseImages: responseImages,
            isWebSocket: false
        )

        log(entry)
    }

    /// Log a WebSocket event
    func logWebSocketEvent(
        service: APIService,
        eventType: String,
        direction: String, // "send" or "receive"
        summary: String,
        images: [Data] = []
    ) {
        let entry = APILogEntry(
            service: service,
            endpoint: eventType,
            method: direction == "send" ? "→" : "←",
            requestSummary: direction == "send" ? summary : "",
            responseSummary: direction == "receive" ? summary : nil,
            statusCode: nil,
            durationMs: nil,
            error: nil,
            requestImages: direction == "send" ? images : [],
            responseImages: direction == "receive" ? images : [],
            isWebSocket: true
        )

        log(entry)
    }

    /// Clear all log entries
    func clear() {
        entries.removeAll()
        logger.info("API logs cleared")
    }

    /// Get entries filtered by service
    func entries(for service: APIService) -> [APILogEntry] {
        return entries.filter { $0.service == service }
    }

    /// Get error entries only
    func errorEntries() -> [APILogEntry] {
        return entries.filter { !$0.isSuccess }
    }

    /// Export logs as JSON
    func exportAsJSON() -> String? {
        let exportData = entries.map { entry -> [String: Any] in
            var dict: [String: Any] = [
                "id": entry.id.uuidString,
                "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
                "service": entry.service.rawValue,
                "endpoint": entry.endpoint,
                "method": entry.method,
                "requestSummary": entry.requestSummary,
                "isWebSocket": entry.isWebSocket
            ]

            if let response = entry.responseSummary {
                dict["responseSummary"] = response
            }
            if let code = entry.statusCode {
                dict["statusCode"] = code
            }
            if let duration = entry.durationMs {
                dict["durationMs"] = duration
            }
            if let error = entry.error {
                dict["error"] = error
            }
            if !entry.requestImages.isEmpty {
                dict["requestImageCount"] = entry.requestImages.count
            }
            if !entry.responseImages.isEmpty {
                dict["responseImageCount"] = entry.responseImages.count
            }

            return dict
        }

        guard let data = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return json
    }
}

// MARK: - Convenience Extensions

extension APIDebugLogger {

    /// Log OpenAI Chat Completions call
    func logChatCompletion(
        model: String,
        prompt: String,
        response: String?,
        statusCode: Int?,
        durationMs: Int,
        error: String? = nil
    ) {
        let entry = APILogEntry(
            service: .openAIChat,
            endpoint: "chat/completions (\(model))",
            requestSummary: prompt.prefix(200) + (prompt.count > 200 ? "..." : ""),
            responseSummary: response,
            statusCode: statusCode,
            durationMs: durationMs,
            error: error
        )
        log(entry)
    }

    /// Log OpenAI Vision API call
    func logVisionCall(
        prompt: String,
        imageData: Data,
        response: String?,
        statusCode: Int?,
        durationMs: Int,
        error: String? = nil
    ) {
        let entry = APILogEntry(
            service: .openAIVision,
            endpoint: "chat/completions (gpt-4o vision)",
            requestSummary: prompt.prefix(200) + (prompt.count > 200 ? "..." : ""),
            responseSummary: response,
            statusCode: statusCode,
            durationMs: durationMs,
            error: error,
            requestImages: [imageData]
        )
        log(entry)
    }

    /// Log Perplexity Search call
    func logPerplexitySearch(
        query: String,
        response: String?,
        statusCode: Int?,
        durationMs: Int,
        error: String? = nil
    ) {
        let entry = APILogEntry(
            service: .perplexity,
            endpoint: "search",
            requestSummary: "Query: \(query)",
            responseSummary: response,
            statusCode: statusCode,
            durationMs: durationMs,
            error: error
        )
        log(entry)
    }

    /// Log Realtime API image sent
    func logRealtimeImageSent(imageData: Data) {
        let entry = APILogEntry(
            service: .openAIRealtime,
            endpoint: "conversation.item.create (image)",
            method: "→",
            requestSummary: "Image sent to conversation",
            requestImages: [imageData],
            isWebSocket: true
        )
        log(entry)
    }

    /// Log Gemini Live WebSocket event
    func logGeminiLiveEvent(
        eventType: String,
        direction: String, // "send" or "receive"
        summary: String,
        images: [Data] = [],
        error: String? = nil
    ) {
        let entry = APILogEntry(
            service: .geminiLive,
            endpoint: eventType,
            method: direction == "send" ? "→" : "←",
            requestSummary: direction == "send" ? summary : "",
            responseSummary: direction == "receive" ? summary : nil,
            statusCode: nil,
            durationMs: nil,
            error: error,
            requestImages: direction == "send" ? images : [],
            responseImages: direction == "receive" ? images : [],
            isWebSocket: true
        )
        log(entry)
    }

    /// Log Gemini Live video frame sent
    func logGeminiLiveFrameSent(imageData: Data) {
        let entry = APILogEntry(
            service: .geminiLive,
            endpoint: "realtime_input (video frame)",
            method: "→",
            requestSummary: "Video frame sent",
            requestImages: [imageData],
            isWebSocket: true
        )
        log(entry)
    }

    /// Log Gemini Live audio response
    func logGeminiLiveAudioReceived(audioBytes: Int) {
        let entry = APILogEntry(
            service: .geminiLive,
            endpoint: "serverContent (audio)",
            method: "←",
            requestSummary: "",
            responseSummary: "Audio received: \(audioBytes) bytes",
            isWebSocket: true
        )
        log(entry)
    }

    /// Log Gemini Live text response
    func logGeminiLiveTextReceived(text: String) {
        let entry = APILogEntry(
            service: .geminiLive,
            endpoint: "serverContent (text)",
            method: "←",
            requestSummary: "",
            responseSummary: text,
            isWebSocket: true
        )
        log(entry)
    }
}
