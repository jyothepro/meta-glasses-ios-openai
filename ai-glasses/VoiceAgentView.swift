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
    @StateObject private var client = RealtimeAPIClient(apiKey: Config.openAIAPIKey)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Connection status
                    ConnectionStatusSection(
                        state: client.connectionState,
                        isSessionConfigured: client.isSessionConfigured
                    )
                    
                    // Connection controls
                    ConnectionControlsSection(
                        state: client.connectionState,
                        onConnect: {
                            logger.info("🔌 Connect button tapped")
                            client.connect()
                        },
                        onDisconnect: {
                            logger.info("🔌 Disconnect button tapped")
                            client.disconnect()
                        }
                    )
                    
                    // Last event indicator (for debugging)
                    if !client.lastServerEvent.isEmpty {
                        LastEventSection(eventType: client.lastServerEvent)
                    }
                    
                    // Info section
                    InfoSection()
                }
                .padding()
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

// MARK: - Connection Status Section

private struct ConnectionStatusSection: View {
    let state: RealtimeConnectionState
    let isSessionConfigured: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(state.displayText)
                    .font(.headline)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                Label(
                    isSessionConfigured ? "Session Ready" : "Session Not Configured",
                    systemImage: isSessionConfigured ? "checkmark.circle.fill" : "circle.dashed"
                )
                .font(.caption)
                .foregroundColor(isSessionConfigured ? .green : .secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch state {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
}

// MARK: - Connection Controls Section

private struct ConnectionControlsSection: View {
    let state: RealtimeConnectionState
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if case .connected = state {
                Button(action: onDisconnect) {
                    Label("Disconnect", systemImage: "wifi.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button(action: onConnect) {
                    Label("Connect to OpenAI", systemImage: "waveform.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(state == .connecting)
            }
            
            if state == .connecting {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Establishing connection...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if case .error(let message) = state {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Last Event Section

private struct LastEventSection: View {
    let eventType: String
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.down.circle")
                .foregroundColor(.blue)
            Text("Last event:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(eventType)
                .font(.caption.monospaced())
                .foregroundColor(.primary)
            Spacer()
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Info Section

private struct InfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("About Voice Agent", systemImage: "info.circle")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            Text("This is a minimal integration with OpenAI's Realtime API. Audio capture and playback will be added in future updates.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            Text("Current capabilities:")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                CapabilityRow(text: "WebSocket connection", isImplemented: true)
                CapabilityRow(text: "Session configuration", isImplemented: true)
                CapabilityRow(text: "Event monitoring", isImplemented: true)
                CapabilityRow(text: "Microphone capture", isImplemented: false)
                CapabilityRow(text: "Audio playback", isImplemented: false)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct CapabilityRow: View {
    let text: String
    let isImplemented: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isImplemented ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isImplemented ? .green : .secondary)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(isImplemented ? .primary : .secondary)
        }
    }
}

#Preview {
    VoiceAgentView()
}
