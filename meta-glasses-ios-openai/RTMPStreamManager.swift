//
//  RTMPStreamManager.swift
//  meta-glasses-ios-openai
//
//  RTMP streaming manager for live broadcasting to YouTube, Twitch, TikTok, etc.
//

import Foundation
import AVFoundation
import UIKit
import Combine
import os.log
import HaishinKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta-glasses-ios-openai", category: "RTMPStreamManager")

// MARK: - Stream State

enum StreamState: Equatable {
    case idle
    case connecting
    case live
    case reconnecting
    case error(String)

    var displayText: String {
        switch self {
        case .idle:
            return "Ready to stream"
        case .connecting:
            return "Connecting..."
        case .live:
            return "Live"
        case .reconnecting:
            return "Reconnecting..."
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var isLive: Bool {
        if case .live = self { return true }
        return false
    }
}

// MARK: - Stream Quality Preset

enum StreamQualityPreset: String, CaseIterable, Codable {
    case low = "480p"
    case medium = "720p"
    case high = "1080p"

    var resolution: CGSize {
        switch self {
        case .low:
            return CGSize(width: 854, height: 480)
        case .medium:
            return CGSize(width: 1280, height: 720)
        case .high:
            return CGSize(width: 1920, height: 1080)
        }
    }

    var videoBitrate: Int {
        switch self {
        case .low:
            return 1_500_000  // 1.5 Mbps
        case .medium:
            return 3_000_000  // 3 Mbps
        case .high:
            return 6_000_000  // 6 Mbps
        }
    }

    var displayName: String {
        switch self {
        case .low:
            return "480p (1.5 Mbps)"
        case .medium:
            return "720p (3 Mbps)"
        case .high:
            return "1080p (6 Mbps)"
        }
    }
}

// MARK: - Platform Preset

enum StreamPlatformPreset: String, CaseIterable, Codable, Identifiable {
    case youtube = "YouTube"
    case twitch = "Twitch"
    case tiktok = "TikTok"
    case facebook = "Facebook"
    case kick = "Kick"
    case custom = "Custom"

    var id: String { rawValue }

    var defaultRTMPURL: String {
        switch self {
        case .youtube:
            return "rtmp://a.rtmp.youtube.com/live2"
        case .twitch:
            return "rtmp://live.twitch.tv/app"
        case .tiktok:
            return "rtmp://push.tiktokv.com/live"
        case .facebook:
            return "rtmps://live-api-s.facebook.com:443/rtmp"
        case .kick:
            return "rtmp://fa723fc1b171.global-contribute.live-video.net/app"
        case .custom:
            return ""
        }
    }

    var helpText: String {
        switch self {
        case .youtube:
            return "Go to YouTube Studio → Create → Go Live → Stream Key"
        case .twitch:
            return "Go to Twitch Dashboard → Settings → Stream → Primary Stream Key"
        case .tiktok:
            return "Requires 1,000+ followers. Go to TikTok LIVE Center → Get stream key"
        case .facebook:
            return "Go to Facebook Creator Studio → Create Live → Use Stream Key"
        case .kick:
            return "Go to Kick Dashboard → Settings → Stream → Stream Key"
        case .custom:
            return "Enter your RTMP server URL and stream key"
        }
    }

    var iconName: String {
        switch self {
        case .youtube:
            return "play.rectangle.fill"
        case .twitch:
            return "gamecontroller.fill"
        case .tiktok:
            return "music.note"
        case .facebook:
            return "person.2.fill"
        case .kick:
            return "bolt.fill"
        case .custom:
            return "server.rack"
        }
    }
}

// MARK: - Stream Settings

struct StreamSettings: Codable, Equatable {
    var platform: StreamPlatformPreset
    var rtmpURL: String
    var streamKey: String
    var quality: StreamQualityPreset
    var fps: Int
    var audioBitrate: Int

    static let `default` = StreamSettings(
        platform: .youtube,
        rtmpURL: StreamPlatformPreset.youtube.defaultRTMPURL,
        streamKey: "",
        quality: .medium,
        fps: 30,
        audioBitrate: 128_000
    )

    var isConfigured: Bool {
        !rtmpURL.isEmpty && !streamKey.isEmpty
    }

    var fullRTMPURL: String {
        if rtmpURL.hasSuffix("/") {
            return rtmpURL + streamKey
        } else {
            return rtmpURL + "/" + streamKey
        }
    }
}

// MARK: - Stream Statistics

struct StreamStatistics {
    var duration: TimeInterval = 0
    var currentBitrate: Int = 0
    var fps: Double = 0
    var droppedFrames: Int = 0
    var totalBytesSent: Int64 = 0

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var formattedBitrate: String {
        if currentBitrate >= 1_000_000 {
            return String(format: "%.1f Mbps", Double(currentBitrate) / 1_000_000)
        } else {
            return String(format: "%d kbps", currentBitrate / 1000)
        }
    }
}

// MARK: - RTMP Stream Manager

@MainActor
final class RTMPStreamManager: ObservableObject {

    // MARK: - Singleton

    static let shared = RTMPStreamManager()

    // MARK: - Published State

    @Published private(set) var state: StreamState = .idle
    @Published private(set) var statistics: StreamStatistics = StreamStatistics()
    @Published var settings: StreamSettings = .default

    // MARK: - Private Properties

    private var rtmpConnection: RTMPConnection?
    private var rtmpStream: RTMPStream?
    private var startTime: Date?
    private var statisticsTimer: Timer?
    private var frameCount: Int = 0
    private var lastFrameCountCheck: Int = 0
    private var lastFrameCheckTime: Date?

    // Audio capture
    private var audioEngine: AVAudioEngine?
    private var audioConverter: AVAudioConverter?

    // MARK: - Initialization

    private init() {
        loadSettings()
    }

    // MARK: - Public Methods

    /// Start streaming to configured RTMP server
    func startStreaming() async throws {
        guard settings.isConfigured else {
            throw StreamError.notConfigured
        }

        guard state != .live && state != .connecting else {
            logger.warning("Already streaming or connecting")
            return
        }

        logger.info("Starting RTMP stream to \(self.settings.platform.rawValue)")
        state = .connecting

        do {
            try await setupAndConnect()
        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    /// Stop streaming
    func stopStreaming() {
        logger.info("Stopping RTMP stream")

        statisticsTimer?.invalidate()
        statisticsTimer = nil

        rtmpStream?.close()
        rtmpConnection?.close()

        stopAudioCapture()

        rtmpStream = nil
        rtmpConnection = nil
        startTime = nil
        frameCount = 0

        state = .idle
        statistics = StreamStatistics()

        logger.info("RTMP stream stopped")
    }

    /// Append a video frame to the stream
    func appendVideoFrame(_ image: UIImage) {
        guard state == .live, let rtmpStream = rtmpStream else { return }

        // Convert UIImage to CMSampleBuffer and append
        guard let cgImage = image.cgImage else { return }

        let ciImage = CIImage(cgImage: cgImage)

        // Create pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: Int(settings.quality.resolution.width),
            kCVPixelBufferHeightKey as String: Int(settings.quality.resolution.height)
        ]

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(settings.quality.resolution.width),
            Int(settings.quality.resolution.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard let buffer = pixelBuffer else { return }

        let context = CIContext()
        context.render(ciImage, to: buffer)

        // Append to stream
        rtmpStream.append(buffer, when: CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 1000000000))

        frameCount += 1
    }

    /// Append audio sample buffer to the stream
    func appendAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard state == .live, let rtmpStream = rtmpStream else { return }
        rtmpStream.append(sampleBuffer)
    }

    /// Save settings to disk
    func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            let url = getSettingsURL()
            try data.write(to: url, options: .atomic)
            logger.info("Stream settings saved")
        } catch {
            logger.error("Failed to save stream settings: \(error.localizedDescription)")
        }
    }

    /// Test connection without starting stream
    func testConnection() async -> Bool {
        guard settings.isConfigured else { return false }

        let testConnection = RTMPConnection()

        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                // Parse URL components
                let urlString = settings.fullRTMPURL

                testConnection.connect(urlString)

                // Wait briefly and check status
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

                let isConnected = testConnection.connected
                testConnection.close()

                continuation.resume(returning: isConnected)
            }
        }
    }

    // MARK: - Private Methods

    private func setupAndConnect() async throws {
        // Create RTMP connection
        rtmpConnection = RTMPConnection()

        guard let connection = rtmpConnection else {
            throw StreamError.connectionFailed
        }

        // Create RTMP stream
        rtmpStream = RTMPStream(connection: connection)

        guard let stream = rtmpStream else {
            throw StreamError.streamCreationFailed
        }

        // Configure video settings
        await stream.setVideoSettings(
            VideoCodecSettings(
                videoSize: settings.quality.resolution,
                bitRate: settings.quality.videoBitrate,
                frameInterval: Double(settings.fps)
            )
        )

        // Configure audio settings
        await stream.setAudioSettings(
            AudioCodecSettings(
                bitRate: settings.audioBitrate
            )
        )

        // Connect to server
        let urlString = settings.fullRTMPURL
        logger.info("Connecting to: \(urlString.prefix(50))...")

        connection.connect(urlString)

        // Wait for connection
        try await waitForConnection()

        // Start publishing
        await stream.publish()

        state = .live
        startTime = Date()
        startStatisticsTimer()
        startAudioCapture()

        logger.info("RTMP stream is now live!")
    }

    private func waitForConnection() async throws {
        // Poll for connection status
        for _ in 0..<30 { // 30 attempts, 100ms each = 3 seconds timeout
            try await Task.sleep(nanoseconds: 100_000_000)

            if let connection = rtmpConnection, connection.connected {
                return
            }
        }

        throw StreamError.connectionTimeout
    }

    private func startStatisticsTimer() {
        lastFrameCheckTime = Date()
        lastFrameCountCheck = frameCount

        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStatistics()
            }
        }
    }

    private func updateStatistics() {
        guard let startTime = startTime else { return }

        let now = Date()
        statistics.duration = now.timeIntervalSince(startTime)

        // Calculate FPS
        if let lastCheck = lastFrameCheckTime {
            let elapsed = now.timeIntervalSince(lastCheck)
            let framesDelta = frameCount - lastFrameCountCheck
            statistics.fps = Double(framesDelta) / elapsed
        }
        lastFrameCheckTime = now
        lastFrameCountCheck = frameCount

        // Get bitrate from stream if available
        if let stream = rtmpStream {
            statistics.currentBitrate = settings.quality.videoBitrate
        }
    }

    private func startAudioCapture() {
        // Audio capture will be handled by GlassesManager routing audio to us
        logger.info("Audio capture ready - waiting for audio from glasses")
    }

    private func stopAudioCapture() {
        audioEngine?.stop()
        audioEngine = nil
        audioConverter = nil
    }

    private func loadSettings() {
        let url = getSettingsURL()

        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.info("No stream settings found, using defaults")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            settings = try JSONDecoder().decode(StreamSettings.self, from: data)
            logger.info("Stream settings loaded")
        } catch {
            logger.error("Failed to load stream settings: \(error.localizedDescription)")
        }
    }

    private func getSettingsURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("stream_settings.json")
    }
}

// MARK: - Stream Errors

enum StreamError: LocalizedError {
    case notConfigured
    case connectionFailed
    case streamCreationFailed
    case connectionTimeout
    case alreadyStreaming

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Stream not configured. Please set RTMP URL and stream key."
        case .connectionFailed:
            return "Failed to create RTMP connection"
        case .streamCreationFailed:
            return "Failed to create RTMP stream"
        case .connectionTimeout:
            return "Connection timed out. Check your RTMP URL and network."
        case .alreadyStreaming:
            return "Already streaming"
        }
    }
}
