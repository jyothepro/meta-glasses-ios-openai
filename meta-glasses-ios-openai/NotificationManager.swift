//
//  NotificationManager.swift
//  meta-glasses-ios-openai
//
//  Created by AI Assistant on 27/01/2026.
//

import Foundation
import AVFoundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta-glasses-ios-openai", category: "NotificationManager")

/// Manages push notifications to Meta glasses via Bluetooth audio
/// This enables proactive notifications to be spoken through glasses speakers
@MainActor
final class NotificationManager: NSObject, ObservableObject {

    static let shared = NotificationManager()

    private let synthesizer = AVSpeechSynthesizer()
    private let audioSession = AVAudioSession.sharedInstance()

    @Published var isSpeaking: Bool = false
    @Published var lastNotification: String = ""
    @Published var audioRoutedToGlasses: Bool = false

    private override init() {
        super.init()
        synthesizer.delegate = self
        checkAudioRoute()
    }

    // MARK: - Audio Route Configuration

    /// Configure audio session to route through Bluetooth (glasses speakers)
    func configureForGlassesSpeakers() {
        do {
            // Allow Bluetooth A2DP for audio output AND HFP for mic input
            try audioSession.setCategory(
                .playAndRecord,
                mode: .spokenAudio,  // Optimized for speech
                options: [.allowBluetoothA2DP, .allowBluetooth]
            )
            try audioSession.setActive(true)

            checkAudioRoute()
            logger.info("✅ Audio session configured for glasses speakers")

        } catch {
            logger.error("❌ Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    /// Check current audio output route
    func checkAudioRoute() {
        let outputs = audioSession.currentRoute.outputs

        audioRoutedToGlasses = outputs.contains { output in
            output.portType == .bluetoothA2DP ||
            output.portType == .bluetoothHFP ||
            output.portType == .bluetoothLE
        }

        let routeDescription = outputs.map { "\($0.portName) (\($0.portType.rawValue))" }.joined(separator: ", ")
        logger.info("🔊 Audio output route: \(routeDescription)")
        logger.info("🎧 Routed to glasses: \(self.audioRoutedToGlasses)")
    }

    /// Get description of current audio output
    func getAudioOutputDescription() -> String {
        let outputs = audioSession.currentRoute.outputs
        if outputs.isEmpty {
            return "No output"
        }
        return outputs.map { $0.portName }.joined(separator: ", ")
    }

    // MARK: - Push Notification to Glasses

    /// Speak a notification through the glasses speakers
    /// - Parameters:
    ///   - message: The text to speak
    ///   - priority: Optional priority prefix (e.g., "Urgent", "Important")
    func pushNotification(_ message: String, priority: String? = nil) {
        // Configure audio route first
        configureForGlassesSpeakers()

        // Build the full message
        var fullMessage = message
        if let priority = priority {
            fullMessage = "\(priority). \(message)"
        }

        lastNotification = fullMessage

        // Create utterance
        let utterance = AVSpeechUtterance(string: fullMessage)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9  // Slightly slower for clarity
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        isSpeaking = true
        synthesizer.speak(utterance)

        logger.info("📢 Pushing notification to glasses: \(fullMessage)")
    }

    /// Send a test notification
    func sendTestNotification() {
        let testMessages = [
            "This is a test notification from your glasses.",
            "Hey! Just checking if you can hear me through your glasses.",
            "Notification test successful. Your glasses are connected.",
            "Testing push notifications. If you hear this, it's working!"
        ]

        let message = testMessages.randomElement() ?? testMessages[0]
        pushNotification(message, priority: "Test")
    }

    /// Simulate an important notification (like a job offer)
    func sendImportantNotification() {
        pushNotification(
            "You just received an email from Google Recruiting. Subject: Your Offer Letter. Would you like me to read the details?",
            priority: "Important"
        )
    }

    /// Stop speaking
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension NotificationManager: AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
            logger.info("🔊 Started speaking notification")
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            logger.info("✅ Finished speaking notification")
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            logger.info("⚠️ Notification speech cancelled")
        }
    }
}
