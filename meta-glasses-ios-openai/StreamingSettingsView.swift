//
//  StreamingSettingsView.swift
//  meta-glasses-ios-openai
//
//  Settings UI for configuring RTMP live streaming
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta-glasses-ios-openai", category: "StreamingSettingsView")

// MARK: - Streaming Settings View

struct StreamingSettingsView: View {
    @ObservedObject private var streamManager = RTMPStreamManager.shared
    @State private var isTestingConnection: Bool = false
    @State private var testResult: TestResult?
    @State private var showStreamKeyAlert: Bool = false

    enum TestResult {
        case success
        case failure
    }

    var body: some View {
        Form {
            // Platform Selection
            Section {
                Picker("Platform", selection: $streamManager.settings.platform) {
                    ForEach(StreamPlatformPreset.allCases) { platform in
                        Label(platform.rawValue, systemImage: platform.iconName)
                            .tag(platform)
                    }
                }
                .onChange(of: streamManager.settings.platform) { _, newPlatform in
                    // Update RTMP URL when platform changes
                    if newPlatform != .custom {
                        streamManager.settings.rtmpURL = newPlatform.defaultRTMPURL
                    }
                    streamManager.saveSettings()
                }

                Text(streamManager.settings.platform.helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Platform")
            }

            // Connection Settings
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RTMP URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("rtmp://...", text: $streamManager.settings.rtmpURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: streamManager.settings.rtmpURL) { _, _ in
                            streamManager.saveSettings()
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Stream Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            showStreamKeyAlert = true
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    SecureField("Enter stream key", text: $streamManager.settings.streamKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: streamManager.settings.streamKey) { _, _ in
                            streamManager.saveSettings()
                        }
                }

                // Test Connection Button
                Button {
                    testConnection()
                } label: {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: testResultIcon)
                                .foregroundColor(testResultColor)
                        }
                        Text(testButtonText)
                    }
                }
                .disabled(isTestingConnection || !streamManager.settings.isConfigured)
            } header: {
                Text("Connection")
            } footer: {
                if !streamManager.settings.isConfigured {
                    Text("Enter RTMP URL and stream key to enable streaming")
                        .foregroundColor(.orange)
                }
            }

            // Quality Settings
            Section {
                Picker("Resolution", selection: $streamManager.settings.quality) {
                    ForEach(StreamQualityPreset.allCases, id: \.self) { quality in
                        Text(quality.displayName)
                            .tag(quality)
                    }
                }
                .onChange(of: streamManager.settings.quality) { _, _ in
                    streamManager.saveSettings()
                }

                Picker("Frame Rate", selection: $streamManager.settings.fps) {
                    Text("24 fps").tag(24)
                    Text("30 fps").tag(30)
                }
                .onChange(of: streamManager.settings.fps) { _, _ in
                    streamManager.saveSettings()
                }

                HStack {
                    Text("Audio Bitrate")
                    Spacer()
                    Text("\(streamManager.settings.audioBitrate / 1000) kbps")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Quality")
            } footer: {
                Text("Higher quality requires more bandwidth. 720p @ 3 Mbps recommended for most connections.")
            }

            // Estimated Requirements
            Section {
                HStack {
                    Text("Upload Speed Required")
                    Spacer()
                    Text(estimatedBandwidth)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Data Usage (per hour)")
                    Spacer()
                    Text(estimatedDataUsage)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Requirements")
            }

            // Platform Links
            Section {
                ForEach(StreamPlatformPreset.allCases.filter { $0 != .custom }) { platform in
                    Link(destination: platformURL(for: platform)) {
                        HStack {
                            Image(systemName: platform.iconName)
                            Text("\(platform.rawValue) Stream Settings")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Get Stream Key")
            }
        }
        .navigationTitle("Streaming")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Stream Key", isPresented: $showStreamKeyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your stream key is like a password. Never share it publicly. Anyone with your stream key can broadcast to your channel.")
        }
    }

    // MARK: - Computed Properties

    private var testButtonText: String {
        if isTestingConnection {
            return "Testing..."
        }
        switch testResult {
        case .success:
            return "Connection OK"
        case .failure:
            return "Connection Failed"
        case nil:
            return "Test Connection"
        }
    }

    private var testResultIcon: String {
        switch testResult {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "xmark.circle.fill"
        case nil:
            return "antenna.radiowaves.left.and.right"
        }
    }

    private var testResultColor: Color {
        switch testResult {
        case .success:
            return .green
        case .failure:
            return .red
        case nil:
            return .blue
        }
    }

    private var estimatedBandwidth: String {
        let totalBitrate = streamManager.settings.quality.videoBitrate + streamManager.settings.audioBitrate
        let mbps = Double(totalBitrate) / 1_000_000
        return String(format: "%.1f Mbps", mbps * 1.2) // 20% overhead
    }

    private var estimatedDataUsage: String {
        let totalBitrate = streamManager.settings.quality.videoBitrate + streamManager.settings.audioBitrate
        let bytesPerHour = Double(totalBitrate) / 8 * 3600
        let gbPerHour = bytesPerHour / 1_000_000_000
        return String(format: "%.1f GB", gbPerHour)
    }

    // MARK: - Methods

    private func testConnection() {
        isTestingConnection = true
        testResult = nil

        Task {
            let success = await streamManager.testConnection()
            await MainActor.run {
                isTestingConnection = false
                testResult = success ? .success : .failure
            }
        }
    }

    private func platformURL(for platform: StreamPlatformPreset) -> URL {
        switch platform {
        case .youtube:
            return URL(string: "https://studio.youtube.com/channel/UC/livestreaming")!
        case .twitch:
            return URL(string: "https://dashboard.twitch.tv/settings/stream")!
        case .tiktok:
            return URL(string: "https://www.tiktok.com/live/creator-settings")!
        case .facebook:
            return URL(string: "https://www.facebook.com/live/producer")!
        case .kick:
            return URL(string: "https://kick.com/dashboard/settings/stream")!
        case .custom:
            return URL(string: "https://www.google.com")!
        }
    }
}

// MARK: - Stream Control View (for GlassesTab)

struct StreamControlView: View {
    @ObservedObject var streamManager = RTMPStreamManager.shared
    @ObservedObject var glassesManager: GlassesManager
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // Status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                Text(streamManager.state.displayText)
                    .font(.headline)
                Spacer()
                if streamManager.state.isLive {
                    Text(streamManager.statistics.formattedDuration)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.red)
                }
            }

            // Statistics (when live)
            if streamManager.state.isLive {
                HStack(spacing: 24) {
                    VStack {
                        Text(streamManager.statistics.formattedBitrate)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Bitrate")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text(String(format: "%.0f", streamManager.statistics.fps))
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("FPS")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text(streamManager.settings.platform.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Platform")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            // Control Button
            Button {
                toggleStreaming()
            } label: {
                HStack {
                    Image(systemName: streamManager.state.isLive ? "stop.fill" : "play.fill")
                    Text(streamManager.state.isLive ? "Stop Streaming" : "Go Live")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(streamManager.state.isLive ? Color.red : Color.blue)
                .cornerRadius(12)
            }
            .disabled(!canStream)

            // Warning if not configured
            if !streamManager.settings.isConfigured {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Configure streaming in Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Warning if glasses not streaming
            if glassesManager.connectionState != .streaming && !streamManager.state.isLive {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Start glasses preview first")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
        .alert("Streaming Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch streamManager.state {
        case .idle:
            return .gray
        case .connecting, .reconnecting:
            return .orange
        case .live:
            return .red
        case .error:
            return .red
        }
    }

    private var canStream: Bool {
        streamManager.settings.isConfigured &&
        (glassesManager.connectionState == .streaming || streamManager.state.isLive)
    }

    // MARK: - Methods

    private func toggleStreaming() {
        if streamManager.state.isLive {
            streamManager.stopStreaming()
        } else {
            Task {
                do {
                    try await streamManager.startStreaming()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StreamingSettingsView()
    }
}
