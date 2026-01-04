//
//  VoiceAgentView.swift
//  ai-glasses
//
//  Voice Agent tab with OpenAI Realtime API integration
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ai-glasses", category: "VoiceAgentView")

struct VoiceAgentView: View {
    @ObservedObject var glassesManager: GlassesManager
    @StateObject private var client: RealtimeAPIClient
    
    init(glassesManager: GlassesManager) {
        self.glassesManager = glassesManager
        self._client = StateObject(wrappedValue: RealtimeAPIClient(
            apiKey: Config.openAIAPIKey,
            glassesManager: glassesManager
        ))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if client.connectionState == .connected {
                    // Connected state: show conversation UI
                    ConnectedView(
                        client: client,
                        onDisconnect: {
                            logger.info("🔌 Disconnect button tapped")
                            client.disconnect()
                        },
                        onStartListening: {
                            logger.info("🎤 Start listening tapped")
                            client.startListening()
                        },
                        onStopListening: {
                            logger.info("🎤 Stop listening tapped")
                            client.stopListening()
                        },
                        onForceResponse: {
                            logger.info("🔘 Force response tapped")
                            client.forceResponse()
                        }
                    )
                } else {
                    // Disconnected/connecting/error state: show welcome screen
                    WelcomeView(
                        connectionState: client.connectionState,
                        onConnect: {
                            logger.info("🔌 Connect button tapped")
                            client.connect()
                        }
                    )
                }
            }
            .navigationTitle("Voice Agent")
            .onAppear {
                logger.info("📱 Voice Agent tab appeared")
            }
            .onDisappear {
                logger.info("📱 Voice Agent tab disappeared")
            }
        }
    }
}

// MARK: - Welcome View (Disconnected State)

private struct WelcomeView: View {
    let connectionState: RealtimeConnectionState
    let onConnect: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Text
                VStack(spacing: 12) {
                    Text("Voice Assistant")
                        .font(.title.bold())
                    
                    Text("Have a natural conversation with AI.\nAsk questions, get help, or just chat.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Action button or status
                VStack(spacing: 16) {
                    if connectionState == .connecting {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Connecting...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 16)
                    } else if case .error(let message) = connectionState {
                        VStack(spacing: 12) {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                            Button(action: onConnect) {
                                Label("Try Again", systemImage: "arrow.clockwise")
                                    .font(.headline)
                                    .frame(maxWidth: 240)
                                    .padding(.vertical, 16)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        }
                    } else {
                        Button(action: onConnect) {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                Text("Start Discussion")
                            }
                            .font(.headline)
                            .frame(maxWidth: 240)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
            }
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Connected View

private struct ConnectedView: View {
    @ObservedObject var client: RealtimeAPIClient
    let onDisconnect: () -> Void
    let onStartListening: () -> Void
    let onStopListening: () -> Void
    let onForceResponse: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Session status (compact)
                    SessionStatusBar(
                        isSessionConfigured: client.isSessionConfigured,
                        voiceState: client.voiceState
                    )
                    
                    // Transcript area
                    TranscriptCard(
                        messages: client.messages,
                        currentUserTranscript: client.userTranscript,
                        currentAssistantTranscript: client.assistantTranscript,
                        voiceState: client.voiceState
                    )
                }
                .padding()
            }
            
            // Bottom controls
            ControlBar(
                voiceState: client.voiceState,
                audioLevel: client.audioLevel,
                onDisconnect: onDisconnect,
                onStartListening: onStartListening,
                onStopListening: onStopListening,
                onForceResponse: onForceResponse
            )
        }
    }
}

// MARK: - Session Status Bar

private struct SessionStatusBar: View {
    let isSessionConfigured: Bool
    let voiceState: VoiceState
    
    var body: some View {
        HStack(spacing: 12) {
            // Session status
            HStack(spacing: 6) {
                Circle()
                    .fill(isSessionConfigured ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(isSessionConfigured ? "Connected" : "Configuring...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Voice state badge
            Text(voiceStateText)
                .font(.caption.bold())
                .foregroundColor(voiceStateColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(voiceStateColor.opacity(0.15))
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var voiceStateText: String {
        switch voiceState {
        case .idle: return "Ready"
        case .listening: return "Listening..."
        case .processing: return "Thinking..."
        case .speaking: return "Speaking..."
        }
    }
    
    private var voiceStateColor: Color {
        switch voiceState {
        case .idle: return .secondary
        case .listening: return .red
        case .processing: return .orange
        case .speaking: return .purple
        }
    }
}

// MARK: - Transcript Card

private struct TranscriptCard: View {
    let messages: [ChatMessage]
    let currentUserTranscript: String
    let currentAssistantTranscript: String
    let voiceState: VoiceState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Conversation")
                .font(.headline)
            
            if messages.isEmpty && currentUserTranscript.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Tap the microphone to start talking")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 32)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // All previous messages
                    ForEach(messages) { message in
                        MessageBubble(
                            text: message.text,
                            isUser: message.isUser,
                            isComplete: true
                        )
                    }
                    
                    // Current streaming assistant transcript (before it's finalized)
                    if voiceState == .speaking && !currentAssistantTranscript.isEmpty {
                        if messages.last?.text != currentAssistantTranscript {
                            MessageBubble(
                                text: currentAssistantTranscript,
                                isUser: false,
                                isComplete: false
                            )
                        }
                    }
                    
                    // Processing indicator
                    if voiceState == .processing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct MessageBubble: View {
    let text: String
    let isUser: Bool
    let isComplete: Bool
    
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: isUser ? "person.fill" : "sparkles")
                        .font(.caption)
                        .foregroundColor(isUser ? .blue : .purple)
                    Text(isUser ? "You" : "Assistant")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                
                Text(text)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isUser ? Color.blue.opacity(0.2) : Color.purple.opacity(0.2))
                    .cornerRadius(12)
            }
            
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Control Bar (Connected State Only)

private struct ControlBar: View {
    let voiceState: VoiceState
    let audioLevel: Float
    let onDisconnect: () -> Void
    let onStartListening: () -> Void
    let onStopListening: () -> Void
    let onForceResponse: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Divider()
            
            // Smart detection hint
            if voiceState == .idle || voiceState == .listening {
                Text("AI will detect when you're ready for a response")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Voice controls
            HStack(spacing: 20) {
                // Disconnect button
                Button(action: onDisconnect) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // Microphone button
                MicrophoneButton(
                    voiceState: voiceState,
                    audioLevel: audioLevel,
                    onStartListening: onStartListening,
                    onStopListening: onStopListening
                )
                
                Spacer()
                
                // Force response button (fallback if user forgot trigger phrase)
                Button(action: onForceResponse) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .disabled(voiceState == .speaking || voiceState == .processing)
                .opacity(voiceState == .speaking || voiceState == .processing ? 0.4 : 1.0)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Microphone Button

private struct MicrophoneButton: View {
    let voiceState: VoiceState
    let audioLevel: Float
    let onStartListening: () -> Void
    let onStopListening: () -> Void
    
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: {
            if voiceState == .idle {
                onStartListening()
            } else if voiceState == .listening {
                onStopListening()
            }
        }) {
            ZStack {
                // Pulsing background when listening
                if voiceState == .listening {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 80 + CGFloat(audioLevel * 30), height: 80 + CGFloat(audioLevel * 30))
                        .animation(.easeInOut(duration: 0.1), value: audioLevel)
                }
                
                // Main button circle
                Circle()
                    .fill(buttonColor)
                    .frame(width: 72, height: 72)
                    .shadow(color: buttonColor.opacity(0.4), radius: 8, x: 0, y: 4)
                
                // Icon
                Image(systemName: buttonIcon)
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .disabled(voiceState == .processing || voiceState == .speaking)
        .opacity(voiceState == .processing || voiceState == .speaking ? 0.6 : 1.0)
    }
    
    private var buttonColor: Color {
        switch voiceState {
        case .idle: return .blue
        case .listening: return .red
        case .processing: return .orange
        case .speaking: return .purple
        }
    }
    
    private var buttonIcon: String {
        switch voiceState {
        case .idle: return "mic.fill"
        case .listening: return "stop.fill"
        case .processing: return "ellipsis"
        case .speaking: return "speaker.wave.2.fill"
        }
    }
}

#Preview {
    VoiceAgentView(glassesManager: GlassesManager())
}
