//
//  GeminiLiveClient.swift
//  meta-glasses-ios-openai
//
//  Gemini Live API client for real-time video streaming and audio responses
//  Used specifically for gym coaching with continuous form analysis
//

import Foundation
import UIKit
import AVFoundation
import Combine
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta-glasses-ios-openai", category: "GeminiLiveClient")

// MARK: - Gemini Live State

enum GeminiLiveState: Equatable {
    case disconnected
    case connecting
    case connected
    case streaming
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        if case .streaming = self { return true }
        return false
    }
}

// MARK: - Gemini Live Client

@MainActor
final class GeminiLiveClient: NSObject, ObservableObject {

    // MARK: - Published State

    @Published private(set) var state: GeminiLiveState = .disconnected
    @Published private(set) var lastTranscript: String = ""

    // MARK: - Callbacks

    var onAudioReceived: ((Data) -> Void)?
    var onTextReceived: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Private Properties

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var isReceiving = false

    // Audio playback
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFormat: AVAudioFormat?

    // Video streaming
    private var videoStreamTask: Task<Void, Never>?
    private var frameProvider: (() -> UIImage?)?
    private var systemInstruction: String = ""

    // Frame rate control
    private let targetFPS: Double = 1.0 // 1 frame per second for cost efficiency

    // Frame counter for logging (don't log every frame)
    private var framesSent: Int = 0

    // MARK: - Initialization

    override init() {
        super.init()
        setupAudioEngine()
    }

    deinit {
        // Clean up without calling MainActor-isolated methods
        isReceiving = false
        videoStreamTask?.cancel()
        webSocket?.cancel(with: .normalClosure, reason: nil)
        urlSession?.invalidateAndCancel()
        playerNode?.stop()
        audioEngine?.stop()
    }

    // MARK: - Public Methods

    /// Connect to Gemini Live API with a system instruction for coaching
    func connect(systemInstruction: String) async throws {
        if case .error = state {
            // Allow reconnect attempts after any previous error state
        } else if state != .disconnected {
            logger.warning("Already connected or connecting")
            return
        }

        let apiKey = SettingsManager.shared.geminiAPIKey
        guard !apiKey.isEmpty else {
            throw GeminiLiveError.noAPIKey
        }

        self.systemInstruction = systemInstruction
        state = .connecting

        // Build WebSocket URL with API key
        let baseURL = Constants.geminiLiveAPIURL
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw GeminiLiveError.invalidURL
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = urlComponents.url else {
            throw GeminiLiveError.invalidURL
        }

        logger.info("🎥 Connecting to Gemini Live API...")

        // Create URLSession and WebSocket
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        webSocket = urlSession?.webSocketTask(with: request)
        webSocket?.resume()

        // Start receiving messages
        isReceiving = true
        receiveMessages()

        // Send setup message
        try await sendSetupMessage()

        state = .connected
        logger.info("🎥 Connected to Gemini Live API")

        // Log connection event
        await APIDebugLogger.shared.logGeminiLiveEvent(
            eventType: "connect",
            direction: "send",
            summary: "Connected to Gemini Live API (model: \(Constants.geminiLiveModel))"
        )
    }

    /// Start streaming video frames from the provided frame source
    func startVideoStream(frameProvider: @escaping () -> UIImage?) {
        guard state.isConnected else {
            logger.warning("Cannot start video stream - not connected")
            return
        }

        self.frameProvider = frameProvider
        state = .streaming

        videoStreamTask = Task {
            await streamVideoFrames()
        }

        logger.info("🎥 Video streaming started")
    }

    /// Stop video streaming but keep connection alive
    func stopVideoStream() {
        videoStreamTask?.cancel()
        videoStreamTask = nil
        frameProvider = nil

        if state == .streaming {
            state = .connected
        }

        logger.info("🎥 Video streaming stopped")
    }

    /// Send a text message to Gemini
    func sendText(_ text: String) async throws {
        guard state.isConnected else {
            throw GeminiLiveError.notConnected
        }

        let message: [String: Any] = [
            "client_content": [
                "turns": [
                    [
                        "role": "user",
                        "parts": [
                            ["text": text]
                        ]
                    ]
                ],
                "turn_complete": true
            ]
        ]

        try await sendJSON(message)
        logger.info("🎥 Sent text: \(text)")
    }

    /// Disconnect from Gemini Live API
    func disconnect() {
        logger.info("🎥 Disconnecting from Gemini Live API")

        // Log disconnect with frame count
        APIDebugLogger.shared.logGeminiLiveEvent(
            eventType: "disconnect",
            direction: "send",
            summary: "Disconnected after \(framesSent) frames sent"
        )

        isReceiving = false
        videoStreamTask?.cancel()
        videoStreamTask = nil
        frameProvider = nil
        framesSent = 0

        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil

        stopAudioPlayback()

        state = .disconnected
    }

    // MARK: - Private Methods - Setup

    private func sendSetupMessage() async throws {
        let setupMessage: [String: Any] = [
            "setup": [
                "model": "models/\(Constants.geminiLiveModel)",
                "generation_config": [
                    "response_modalities": ["AUDIO"],
                    "speech_config": [
                        "voice_config": [
                            "prebuilt_voice_config": [
                                "voice_name": "Aoede"
                            ]
                        ]
                    ]
                ],
                "system_instruction": [
                    "parts": [
                        ["text": systemInstruction]
                    ]
                ]
            ]
        ]

        try await sendJSON(setupMessage)
        logger.info("🎥 Sent setup message")

        // Log setup message
        await APIDebugLogger.shared.logGeminiLiveEvent(
            eventType: "setup",
            direction: "send",
            summary: "System: \(systemInstruction.prefix(100))..."
        )
    }

    // MARK: - Private Methods - Video Streaming

    private func streamVideoFrames() async {
        let frameInterval = 1.0 / targetFPS

        while !Task.isCancelled && state == .streaming {
            // Get frame from provider
            if let frame = await MainActor.run(body: { frameProvider?() }),
               let imageData = frame.jpegData(compressionQuality: 0.6) {

                let base64Image = imageData.base64EncodedString()

                // Send frame as realtime input
                let frameMessage: [String: Any] = [
                    "realtime_input": [
                        "media_chunks": [
                            [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]

                do {
                    try await sendJSON(frameMessage)
                    framesSent += 1
                    logger.debug("🎥 Sent video frame #\(self.framesSent)")

                    // Log every 10th frame to API debug log (avoid spam)
                    if framesSent % 10 == 1 {
                        await APIDebugLogger.shared.logGeminiLiveFrameSent(imageData: imageData)
                    }
                } catch {
                    logger.error("🎥 Failed to send frame: \(error.localizedDescription)")
                    await APIDebugLogger.shared.logGeminiLiveEvent(
                        eventType: "realtime_input (error)",
                        direction: "send",
                        summary: "Failed to send frame",
                        error: error.localizedDescription
                    )
                }
            }

            // Wait for next frame interval
            try? await Task.sleep(nanoseconds: UInt64(frameInterval * 1_000_000_000))
        }
    }

    // MARK: - Private Methods - WebSocket Communication

    private func sendJSON(_ dict: [String: Any]) async throws {
        guard let webSocket = webSocket else {
            throw GeminiLiveError.notConnected
        }

        let data = try JSONSerialization.data(withJSONObject: dict)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw GeminiLiveError.encodingError
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        try await webSocket.send(message)
    }

    private func receiveMessages() {
        guard isReceiving, let webSocket = webSocket else { return }

        webSocket.receive { [weak self] result in
            guard let self = self else { return }

            Task { @MainActor in
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    // Continue receiving
                    self.receiveMessages()

                case .failure(let error):
                    logger.error("🎥 WebSocket receive error: \(error.localizedDescription)")
                    self.state = .error(error.localizedDescription)
                    self.onError?(error)

                    // Log error
                    APIDebugLogger.shared.logGeminiLiveEvent(
                        eventType: "websocket_error",
                        direction: "receive",
                        summary: "Connection error",
                        error: error.localizedDescription
                    )
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseServerEvent(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseServerEvent(text)
            }
        @unknown default:
            break
        }
    }

    private func parseServerEvent(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.warning("🎥 Failed to parse server event")
            return
        }

        // Log event type for debugging
        let eventTypes = Array(json.keys)
        logger.debug("🎥 Received event: \(eventTypes)")

        // Handle setup complete
        if json["setupComplete"] != nil {
            logger.info("🎥 Setup complete")
            return
        }

        // Handle server content (audio/text responses)
        if let serverContent = json["serverContent"] as? [String: Any] {
            handleServerContent(serverContent)
            return
        }

        // Handle tool calls if any (for future expansion)
        if let toolCall = json["toolCall"] as? [String: Any] {
            handleToolCall(toolCall)
            return
        }
    }

    private func handleServerContent(_ content: [String: Any]) {
        // Check if model turn is complete
        if let turnComplete = content["turnComplete"] as? Bool, turnComplete {
            logger.info("🎥 Turn complete")
        }

        // Handle model turn content
        if let modelTurn = content["modelTurn"] as? [String: Any],
           let parts = modelTurn["parts"] as? [[String: Any]] {

            for part in parts {
                // Handle inline audio data
                if let inlineData = part["inlineData"] as? [String: Any],
                   let mimeType = inlineData["mimeType"] as? String,
                   mimeType.starts(with: "audio/"),
                   let base64Data = inlineData["data"] as? String,
                   let audioData = Data(base64Encoded: base64Data) {

                    logger.debug("🎥 Received audio chunk: \(audioData.count) bytes")
                    playAudioData(audioData)
                    onAudioReceived?(audioData)

                    // Log audio (not every chunk - just significant ones)
                    if audioData.count > 1000 {
                        APIDebugLogger.shared.logGeminiLiveAudioReceived(audioBytes: audioData.count)
                    }
                }

                // Handle text (transcription or direct text)
                if let text = part["text"] as? String {
                    logger.info("🎥 Received text: \(text)")
                    lastTranscript = text
                    onTextReceived?(text)

                    // Log text response
                    APIDebugLogger.shared.logGeminiLiveTextReceived(text: text)
                }
            }
        }
    }

    private func handleToolCall(_ toolCall: [String: Any]) {
        // Reserved for future tool call support
        logger.info("🎥 Received tool call: \(toolCall)")
    }

    // MARK: - Private Methods - Audio Playback

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()

        guard let engine = audioEngine, let player = playerNode else { return }

        // Gemini outputs 24kHz PCM audio
        audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 24000,
            channels: 1,
            interleaved: false
        )

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: audioFormat)

        do {
            try engine.start()
            logger.info("🎥 Audio engine started")
        } catch {
            logger.error("🎥 Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    private func playAudioData(_ data: Data) {
        guard let engine = audioEngine,
              let player = playerNode,
              let format = audioFormat,
              engine.isRunning else {
            return
        }

        // Convert raw PCM data to audio buffer
        let frameCount = UInt32(data.count) / 2 // 16-bit = 2 bytes per sample
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }

        buffer.frameLength = frameCount

        // Copy data to buffer
        data.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                memcpy(buffer.int16ChannelData?[0], baseAddress, data.count)
            }
        }

        // Play the buffer
        if !player.isPlaying {
            player.play()
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    private func stopAudioPlayback() {
        playerNode?.stop()
        audioEngine?.stop()
    }
}

// MARK: - URLSessionWebSocketDelegate

extension GeminiLiveClient: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        logger.info("🎥 WebSocket connection opened")
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        logger.info("🎥 WebSocket closed with code: \(closeCode.rawValue)")
        Task { @MainActor in
            self.state = .disconnected
        }
    }
}

// MARK: - Errors

enum GeminiLiveError: LocalizedError {
    case noAPIKey
    case invalidURL
    case notConnected
    case encodingError
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Gemini API key not configured. Add it in Settings → AI → Models."
        case .invalidURL:
            return "Invalid Gemini API URL"
        case .notConnected:
            return "Not connected to Gemini Live API"
        case .encodingError:
            return "Failed to encode message"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        }
    }
}
