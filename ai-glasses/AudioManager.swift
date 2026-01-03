//
//  AudioManager.swift
//  ai-glasses
//
//  Created by Kirill Markin on 03/01/2026.
//

import Foundation
import AVFoundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ai-glasses", category: "AudioManager")

// MARK: - Audio Manager

/// Manages HFP audio session for Meta Wearables microphone access
final class AudioManager {
    
    private let audioSession = AVAudioSession.sharedInstance()
    private(set) var isConfigured: Bool = false
    
    // MARK: - Audio Session Configuration
    
    /// Configure audio session for HFP (Hands-Free Profile) to access glasses microphone
    /// Must be called BEFORE starting a stream session
    func configureForHFP() throws {
        logger.info("🎤 Configuring audio session for HFP...")
        
        do {
            // Set category to playAndRecord with Bluetooth option for HFP
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetoothHFP, .defaultToSpeaker]
            )
            
            // Activate the audio session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            isConfigured = true
            logger.info("✅ Audio session configured for HFP")
            
            // Log available inputs
            if let inputs = audioSession.availableInputs {
                for input in inputs {
                    logger.info("🎤 Available input: \(input.portName) (\(input.portType.rawValue))")
                }
            }
            
        } catch {
            isConfigured = false
            logger.error("❌ Failed to configure audio session: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Deactivate audio session
    func deactivate() {
        logger.info("🎤 Deactivating audio session...")
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            isConfigured = false
            logger.info("✅ Audio session deactivated")
        } catch {
            logger.warning("⚠️ Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
    
    /// Check if Bluetooth audio input is available
    func isBluetoothInputAvailable() -> Bool {
        guard let inputs = audioSession.availableInputs else { return false }
        
        let bluetoothTypes: [AVAudioSession.Port] = [
            .bluetoothHFP,
            .bluetoothA2DP,
            .bluetoothLE
        ]
        
        return inputs.contains { input in
            bluetoothTypes.contains(input.portType)
        }
    }
    
    /// Get current audio input
    func getCurrentInput() -> AVAudioSessionPortDescription? {
        return audioSession.currentRoute.inputs.first
    }
}
