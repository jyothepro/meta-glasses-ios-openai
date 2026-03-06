//
//  ConversationCaptureView.swift
//  meta-glasses-ios-openai
//
//  Capture tab UI for recording and transcribing conversations
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta-glasses-ios-openai", category: "CaptureView")

struct ConversationCaptureView: View {
    @ObservedObject private var captureManager = ConversationCaptureManager.shared
    @ObservedObject private var store = CaptureStore.shared
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared

    @State private var showCancelConfirmation = false
    @State private var navigateToCaptureId: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if permissionsManager.microphoneStatus != .authorized {
                    micPermissionView
                } else if !settingsManager.isOpenAIConfigured {
                    apiKeyMissingView
                } else {
                    captureContent
                }
            }
            .navigationTitle("Capture")
            .navigationDestination(item: $navigateToCaptureId) { captureId in
                CaptureDetailView(captureId: captureId)
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var captureContent: some View {
        switch captureManager.captureState {
        case .idle:
            idleView
        case .recording:
            recordingView
        case .processing:
            processingView
        case .completed:
            completedView
        case .error(let message):
            errorView(message: message)
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Audio source indicator
                audioSourceBadge

                // Consent disclaimer (first time)
                if !settingsManager.captureConsentAcknowledged {
                    consentCard
                }

                // Start button
                Button(action: {
                    if !settingsManager.captureConsentAcknowledged {
                        settingsManager.captureConsentAcknowledged = true
                    }
                    captureManager.startCapture()
                }) {
                    Label("Start Capture", systemImage: "mic.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                // Recent captures
                if !store.sessions.isEmpty {
                    recentCapturesList
                }
            }
            .padding()
        }
    }

    // MARK: - Recording State

    private var recordingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Pulsing record indicator
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 120 + CGFloat(captureManager.audioLevel * 40),
                           height: 120 + CGFloat(captureManager.audioLevel * 40))
                    .animation(.easeInOut(duration: 0.1), value: captureManager.audioLevel)

                Circle()
                    .fill(Color.red)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.title)
                            .foregroundColor(.white)
                    )
            }

            // Elapsed time
            Text(formatDuration(captureManager.elapsedTime))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundColor(.primary)

            // Audio source
            Label(captureManager.audioSource.displayName, systemImage: captureManager.audioSource == .glasses ? "eyeglasses" : "mic")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            // Stop button
            Button(action: {
                captureManager.stopCapture()
            }) {
                Label("Stop", systemImage: "stop.fill")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            // Cancel option
            Button("Cancel Recording") {
                showCancelConfirmation = true
            }
            .foregroundColor(.secondary)
            .confirmationDialog("Cancel recording?", isPresented: $showCancelConfirmation) {
                Button("Cancel Recording", role: .destructive) {
                    captureManager.cancelCapture()
                }
                Button("Continue Recording", role: .cancel) {}
            } message: {
                Text("The audio will be deleted and cannot be recovered.")
            }
        }
        .padding()
    }

    // MARK: - Processing State

    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text(captureManager.processingStep.isEmpty ? "Processing..." : captureManager.processingStep)
                .font(.headline)

            if let session = captureManager.currentSession {
                Text(formatDuration(session.duration))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Completed State

    private var completedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            if let session = captureManager.currentSession {
                Text(session.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Label(formatDuration(session.duration), systemImage: "clock")
                    Label("\(session.wordCount) words", systemImage: "doc.text")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                if let session = captureManager.currentSession {
                    navigateToCaptureId = session.id
                }
                captureManager.resetToIdle()
            } label: {
                Label("View Details", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            Button {
                captureManager.resetToIdle()
            } label: {
                Text("New Capture")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Error State

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            if captureManager.currentSession?.transcriptStatus == .failed {
                Button {
                    captureManager.retryTranscription()
                } label: {
                    Label("Retry Transcription", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                captureManager.resetToIdle()
            } label: {
                Text("Dismiss")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Components

    private var audioSourceBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: captureManager.audioSource == .glasses ? "eyeglasses" : "mic")
                .foregroundColor(captureManager.audioSource == .glasses ? .green : .blue)
            Text(captureManager.audioSource.displayName)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .onAppear {
            captureManager.refreshAudioSource()
        }
    }

    private var consentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Recording Consent", systemImage: "exclamationmark.shield")
                .font(.headline)
                .foregroundColor(.orange)

            Text("This feature records audio from your surroundings. Please ensure all participants are aware of and consent to being recorded. Recordings are stored locally on your device.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    private var recentCapturesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Captures")
                .font(.headline)

            ForEach(store.sessions.prefix(5)) { session in
                Button {
                    navigateToCaptureId = session.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                Text(formatDate(session.createdAt))
                                Text(formatDuration(session.duration))
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Permission Views

    private var micPermissionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Microphone Access Required")
                .font(.title2.bold())

            Text("Conversation Capture needs microphone access to record audio.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Grant Microphone Access") {
                if permissionsManager.microphoneStatus == .notDetermined {
                    permissionsManager.requestMicrophone()
                } else {
                    permissionsManager.openAppSettings()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var apiKeyMissingView: some View {
        VStack(spacing: 24) {
            Image(systemName: "key")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("OpenAI API Key Required")
                .font(.title2.bold())

            Text("Configure your OpenAI API key in Settings to use Conversation Capture.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Formatters

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
