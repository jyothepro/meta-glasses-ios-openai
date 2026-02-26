//
//  RTMPStreamManager.swift
//  meta-glasses-ios-openai
//
//  RTMP streaming manager for live broadcasting to YouTube, Twitch, TikTok, etc.
//  Using HaishinKit 2.0 API
//

import Foundation
import AVFoundation
import UIKit
import Combine
import os.log
import VideoToolbox
import HaishinKit
import RTMPHaishinKit

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
            return 1_500_000
        case .medium:
            return 3_000_000
        case .high:
            return 6_000_000
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
    private var connectionTask: Task<Void, Never>?

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

        connectionTask = Task {
            await setupAndConnect()
        }
    }

    /// Stop streaming
    func stopStreaming() {
        logger.info("Stopping RTMP stream")

        connectionTask?.cancel()
        connectionTask = nil

        statisticsTimer?.invalidate()
        statisticsTimer = nil

        Task {
            _ = try? await rtmpStream?.close()
            _ = try? await rtmpConnection?.close()
        }

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

        guard let sampleBuffer = image.toCMSampleBuffer(width: Int(settings.quality.resolution.width),
                                                        height: Int(settings.quality.resolution.height)) else {
            return
        }

        Task {
            await rtmpStream.append(sampleBuffer)
        }

        frameCount += 1
    }

    /// Append audio sample buffer to the stream
    func appendAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard state == .live, let rtmpStream = rtmpStream else { return }
        Task {
            await rtmpStream.append(sampleBuffer)
        }
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

        do {
            _ = try await testConnection.connect(settings.rtmpURL)
            logger.info("Test connection successful")
            try? await testConnection.close()
            return true
        } catch {
            logger.error("Test connection failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Methods

    private func setupAndConnect() async {
        // Create RTMP connection
        rtmpConnection = RTMPConnection()

        guard let connection = rtmpConnection else {
            await MainActor.run {
                state = .error("Failed to create connection")
            }
            return
        }

        do {
            // Connect to RTMP server
            logger.info("Connecting to: \(self.settings.rtmpURL)")
            _ = try await connection.connect(settings.rtmpURL)
            logger.info("Connected to RTMP server")

            // Create and configure stream
            await createStreamAndPublish(connection: connection)

        } catch {
            logger.error("Connection failed: \(error.localizedDescription)")
            await MainActor.run {
                state = .error("Connection failed: \(error.localizedDescription)")
            }
        }
    }

    private func createStreamAndPublish(connection: RTMPConnection) async {
        rtmpStream = RTMPStream(connection: connection)

        guard let stream = rtmpStream else {
            await MainActor.run {
                state = .error("Failed to create stream")
            }
            return
        }

        do {
            // Configure video settings
            try await stream.setVideoSettings(
                .init(
                    videoSize: CGSize(
                        width: settings.quality.resolution.width,
                        height: settings.quality.resolution.height
                    ),
                    bitRate: settings.quality.videoBitrate,
                    profileLevel: kVTProfileLevel_H264_Main_AutoLevel as String,
                    maxKeyFrameIntervalDuration: 2
                )
            )

            // Configure audio settings
            try await stream.setAudioSettings(
                .init(
                    bitRate: settings.audioBitrate
                )
            )

            // Publish the stream
            _ = try await stream.publish(settings.streamKey)
            logger.info("Stream published with key")

            await MainActor.run {
                state = .live
                startTime = Date()
                startStatisticsTimer()
            }

            logger.info("RTMP stream is now live!")
        } catch {
            logger.error("Failed to publish stream: \(error.localizedDescription)")
            await MainActor.run {
                state = .error("Failed to publish: \(error.localizedDescription)")
            }
        }
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

        if let lastCheck = lastFrameCheckTime {
            let elapsed = now.timeIntervalSince(lastCheck)
            let framesDelta = frameCount - lastFrameCountCheck
            statistics.fps = Double(framesDelta) / elapsed
        }
        lastFrameCheckTime = now
        lastFrameCountCheck = frameCount

        statistics.currentBitrate = settings.quality.videoBitrate
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
            return "Failed to connect to RTMP server"
        case .streamCreationFailed:
            return "Failed to create RTMP stream"
        case .connectionTimeout:
            return "Connection timed out. Check your RTMP URL and network."
        case .alreadyStreaming:
            return "Already streaming"
        }
    }
}

// MARK: - UIImage Extension for CMSampleBuffer Conversion

extension UIImage {
    func toCMSampleBuffer(width: Int, height: Int) -> CMSampleBuffer? {
        guard let pixelBuffer = toPixelBuffer(width: width, height: height) else {
            return nil
        }

        var sampleBuffer: CMSampleBuffer?
        var formatDescription: CMFormatDescription?

        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )

        guard let format = formatDescription else { return nil }

        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 1_000_000),
            decodeTimeStamp: .invalid
        )

        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }

    func toPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        guard let cgImage = self.cgImage else { return nil }

        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }
}
