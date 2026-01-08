//
//  RTMPStreamManagerTests.swift
//  meta-glasses-ios-openaiTests
//
//  Tests for RTMP streaming functionality
//

import Testing
import Foundation
@testable import meta_glasses_ios_openai

// MARK: - Stream Settings Tests

struct StreamSettingsTests {

    @Test func defaultSettingsAreValid() {
        let settings = StreamSettings.default

        #expect(settings.platform == .youtube)
        #expect(settings.rtmpURL == "rtmp://a.rtmp.youtube.com/live2")
        #expect(settings.streamKey.isEmpty)
        #expect(settings.quality == .medium)
        #expect(settings.fps == 30)
        #expect(settings.audioBitrate == 128_000)
    }

    @Test func isConfiguredReturnsFalseWhenEmpty() {
        var settings = StreamSettings.default
        settings.rtmpURL = ""
        settings.streamKey = ""

        #expect(!settings.isConfigured)
    }

    @Test func isConfiguredReturnsFalseWithOnlyURL() {
        var settings = StreamSettings.default
        settings.rtmpURL = "rtmp://example.com/live"
        settings.streamKey = ""

        #expect(!settings.isConfigured)
    }

    @Test func isConfiguredReturnsFalseWithOnlyKey() {
        var settings = StreamSettings.default
        settings.rtmpURL = ""
        settings.streamKey = "my-stream-key"

        #expect(!settings.isConfigured)
    }

    @Test func isConfiguredReturnsTrueWhenBothSet() {
        var settings = StreamSettings.default
        settings.rtmpURL = "rtmp://example.com/live"
        settings.streamKey = "my-stream-key"

        #expect(settings.isConfigured)
    }

    @Test func fullRTMPURLConcatenatesCorrectly() {
        var settings = StreamSettings.default
        settings.rtmpURL = "rtmp://example.com/live"
        settings.streamKey = "abc123"

        #expect(settings.fullRTMPURL == "rtmp://example.com/live/abc123")
    }

    @Test func fullRTMPURLHandlesTrailingSlash() {
        var settings = StreamSettings.default
        settings.rtmpURL = "rtmp://example.com/live/"
        settings.streamKey = "abc123"

        #expect(settings.fullRTMPURL == "rtmp://example.com/live/abc123")
    }
}

// MARK: - Stream Quality Preset Tests

struct StreamQualityPresetTests {

    @Test func lowQualityValues() {
        let quality = StreamQualityPreset.low

        #expect(quality.resolution.width == 854)
        #expect(quality.resolution.height == 480)
        #expect(quality.videoBitrate == 1_500_000)
        #expect(quality.displayName == "480p (1.5 Mbps)")
    }

    @Test func mediumQualityValues() {
        let quality = StreamQualityPreset.medium

        #expect(quality.resolution.width == 1280)
        #expect(quality.resolution.height == 720)
        #expect(quality.videoBitrate == 3_000_000)
        #expect(quality.displayName == "720p (3 Mbps)")
    }

    @Test func highQualityValues() {
        let quality = StreamQualityPreset.high

        #expect(quality.resolution.width == 1920)
        #expect(quality.resolution.height == 1080)
        #expect(quality.videoBitrate == 6_000_000)
        #expect(quality.displayName == "1080p (6 Mbps)")
    }

    @Test func allCasesContainsThreePresets() {
        #expect(StreamQualityPreset.allCases.count == 3)
    }
}

// MARK: - Stream Platform Preset Tests

struct StreamPlatformPresetTests {

    @Test func youtubePreset() {
        let platform = StreamPlatformPreset.youtube

        #expect(platform.rawValue == "YouTube")
        #expect(platform.defaultRTMPURL == "rtmp://a.rtmp.youtube.com/live2")
        #expect(!platform.helpText.isEmpty)
        #expect(platform.iconName == "play.rectangle.fill")
    }

    @Test func twitchPreset() {
        let platform = StreamPlatformPreset.twitch

        #expect(platform.rawValue == "Twitch")
        #expect(platform.defaultRTMPURL == "rtmp://live.twitch.tv/app")
        #expect(!platform.helpText.isEmpty)
        #expect(platform.iconName == "gamecontroller.fill")
    }

    @Test func tiktokPreset() {
        let platform = StreamPlatformPreset.tiktok

        #expect(platform.rawValue == "TikTok")
        #expect(platform.defaultRTMPURL == "rtmp://push.tiktokv.com/live")
        #expect(platform.helpText.contains("1,000"))
        #expect(platform.iconName == "music.note")
    }

    @Test func facebookPreset() {
        let platform = StreamPlatformPreset.facebook

        #expect(platform.rawValue == "Facebook")
        #expect(platform.defaultRTMPURL.contains("facebook.com"))
        #expect(platform.defaultRTMPURL.hasPrefix("rtmps://")) // Facebook uses secure RTMP
        #expect(platform.iconName == "person.2.fill")
    }

    @Test func kickPreset() {
        let platform = StreamPlatformPreset.kick

        #expect(platform.rawValue == "Kick")
        #expect(!platform.defaultRTMPURL.isEmpty)
        #expect(platform.iconName == "bolt.fill")
    }

    @Test func customPresetHasEmptyURL() {
        let platform = StreamPlatformPreset.custom

        #expect(platform.rawValue == "Custom")
        #expect(platform.defaultRTMPURL.isEmpty)
        #expect(platform.iconName == "server.rack")
    }

    @Test func allCasesContainsSixPlatforms() {
        #expect(StreamPlatformPreset.allCases.count == 6)
    }

    @Test func platformIdentifiersAreUnique() {
        let ids = StreamPlatformPreset.allCases.map { $0.id }
        let uniqueIds = Set(ids)

        #expect(ids.count == uniqueIds.count)
    }
}

// MARK: - Stream State Tests

struct StreamStateTests {

    @Test func idleStateProperties() {
        let state = StreamState.idle

        #expect(state.displayText == "Ready to stream")
        #expect(!state.isLive)
    }

    @Test func connectingStateProperties() {
        let state = StreamState.connecting

        #expect(state.displayText == "Connecting...")
        #expect(!state.isLive)
    }

    @Test func liveStateProperties() {
        let state = StreamState.live

        #expect(state.displayText == "Live")
        #expect(state.isLive)
    }

    @Test func reconnectingStateProperties() {
        let state = StreamState.reconnecting

        #expect(state.displayText == "Reconnecting...")
        #expect(!state.isLive)
    }

    @Test func errorStateProperties() {
        let state = StreamState.error("Network failed")

        #expect(state.displayText == "Error: Network failed")
        #expect(!state.isLive)
    }

    @Test func stateEquality() {
        #expect(StreamState.idle == StreamState.idle)
        #expect(StreamState.live == StreamState.live)
        #expect(StreamState.error("test") == StreamState.error("test"))
        #expect(StreamState.error("a") != StreamState.error("b"))
        #expect(StreamState.idle != StreamState.live)
    }
}

// MARK: - Stream Statistics Tests

struct StreamStatisticsTests {

    @Test func defaultStatisticsAreZero() {
        let stats = StreamStatistics()

        #expect(stats.duration == 0)
        #expect(stats.currentBitrate == 0)
        #expect(stats.fps == 0)
        #expect(stats.droppedFrames == 0)
        #expect(stats.totalBytesSent == 0)
    }

    @Test func formattedDurationWithSeconds() {
        var stats = StreamStatistics()
        stats.duration = 45

        #expect(stats.formattedDuration == "00:45")
    }

    @Test func formattedDurationWithMinutes() {
        var stats = StreamStatistics()
        stats.duration = 125 // 2:05

        #expect(stats.formattedDuration == "02:05")
    }

    @Test func formattedDurationWithHours() {
        var stats = StreamStatistics()
        stats.duration = 3725 // 1:02:05

        #expect(stats.formattedDuration == "1:02:05")
    }

    @Test func formattedBitrateInKbps() {
        var stats = StreamStatistics()
        stats.currentBitrate = 500_000

        #expect(stats.formattedBitrate == "500 kbps")
    }

    @Test func formattedBitrateInMbps() {
        var stats = StreamStatistics()
        stats.currentBitrate = 3_500_000

        #expect(stats.formattedBitrate == "3.5 Mbps")
    }
}

// MARK: - Stream Error Tests

struct StreamErrorTests {

    @Test func notConfiguredError() {
        let error = StreamError.notConfigured

        #expect(error.errorDescription?.contains("not configured") == true)
    }

    @Test func connectionFailedError() {
        let error = StreamError.connectionFailed

        #expect(error.errorDescription?.contains("connection") == true)
    }

    @Test func connectionTimeoutError() {
        let error = StreamError.connectionTimeout

        #expect(error.errorDescription?.contains("timed out") == true)
    }

    @Test func alreadyStreamingError() {
        let error = StreamError.alreadyStreaming

        #expect(error.errorDescription?.contains("streaming") == true)
    }
}
