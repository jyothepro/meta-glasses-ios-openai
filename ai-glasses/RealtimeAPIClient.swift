//
//  RealtimeAPIClient.swift
//  ai-glasses
//
//  WebSocket client for OpenAI Realtime API
//

import Foundation
import Combine
import os.log

// MARK: - Connection State

enum RealtimeConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    var displayText: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - Realtime API Client

@MainActor
final class RealtimeAPIClient: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var connectionState: RealtimeConnectionState = .disconnected
    @Published private(set) var lastServerEvent: String = ""
    @Published private(set) var isSessionConfigured: Bool = false
    
    // MARK: - Private Properties
    
    private var webSocket: URLSessionWebSocketTask?
    private let apiKey: String
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ai-glasses", category: "RealtimeAPI")
    
    private let realtimeURL = "wss://api.openai.com/v1/realtime?model=gpt-realtime"
    
    // MARK: - Initialization
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Public Methods
    
    func connect() {
        guard connectionState == .disconnected || connectionState != .connecting else {
            logger.warning("Already connecting or connected")
            return
        }
        
        connectionState = .connecting
        logger.info("Connecting to Realtime API...")
        
        guard let url = URL(string: realtimeURL) else {
            connectionState = .error("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: request)
        webSocket?.resume()
        
        // Start receiving messages
        receiveMessage()
        
        // Configure session after connection
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5s for connection
            await configureSession()
        }
    }
    
    func disconnect() {
        logger.info("Disconnecting from Realtime API")
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        connectionState = .disconnected
        isSessionConfigured = false
    }
    
    /// Send raw audio data (PCM 24kHz) to the API
    func sendAudio(pcmData: Data) {
        guard connectionState == .connected else {
            logger.warning("Cannot send audio: not connected")
            return
        }
        
        let base64Audio = pcmData.base64EncodedString()
        let event: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]
        send(event: event)
    }
    
    /// Commit the audio buffer (signals end of speech)
    func commitAudioBuffer() {
        let event: [String: String] = [
            "type": "input_audio_buffer.commit"
        ]
        send(event: event)
    }
    
    /// Request a response from the model
    func createResponse() {
        let event: [String: String] = [
            "type": "response.create"
        ]
        send(event: event)
    }
    
    // MARK: - Private Methods
    
    private func configureSession() async {
        logger.info("Configuring session...")
        
        let sessionConfig: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": "You are a helpful voice assistant for smart glasses. Keep responses brief and conversational.",
                "voice": "alloy",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 500
                ]
            ]
        ]
        
        send(event: sessionConfig)
    }
    
    private func send(event: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: event),
              let jsonString = String(data: data, encoding: .utf8) else {
            logger.error("Failed to serialize event")
            return
        }
        
        webSocket?.send(.string(jsonString)) { [weak self] error in
            if let error = error {
                self?.logger.error("Send error: \(error.localizedDescription)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.receiveMessage() // Continue listening
                    
                case .failure(let error):
                    self.logger.error("Receive error: \(error.localizedDescription)")
                    self.connectionState = .error(error.localizedDescription)
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
            logger.warning("Unknown message type received")
        }
    }
    
    private func parseServerEvent(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventType = json["type"] as? String else {
            logger.warning("Failed to parse server event")
            return
        }
        
        lastServerEvent = eventType
        logger.info("Received event: \(eventType)")
        
        switch eventType {
        case "session.created":
            connectionState = .connected
            logger.info("Session created")
            
        case "session.updated":
            isSessionConfigured = true
            logger.info("Session configured")
            
        case "response.audio.delta":
            // Audio chunk received - would play here
            if let delta = json["delta"] as? String {
                logger.debug("Received audio delta: \(delta.prefix(50))...")
            }
            
        case "response.audio_transcript.delta":
            // Transcript of AI response
            if let delta = json["delta"] as? String {
                logger.info("AI transcript: \(delta)")
            }
            
        case "conversation.item.input_audio_transcription.completed":
            // Transcript of user input
            if let transcript = json["transcript"] as? String {
                logger.info("User said: \(transcript)")
            }
            
        case "error":
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                logger.error("Server error: \(message)")
                connectionState = .error(message)
            }
            
        default:
            logger.debug("Unhandled event type: \(eventType)")
        }
    }
}
