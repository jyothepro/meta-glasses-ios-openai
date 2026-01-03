//
//  ContentView.swift
//  ai-glasses
//
//  Created by Kirill Markin on 03/01/2026.
//

import SwiftUI
import MWDATCamera

struct ContentView: View {
    @StateObject private var glassesManager = GlassesManager()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Status section
                StatusSection(
                    state: glassesManager.connectionState,
                    isRegistered: glassesManager.isRegistered,
                    deviceCount: glassesManager.availableDevices.count
                )
                
                // Registration section (if not registered)
                if !glassesManager.isRegistered {
                    RegistrationSection(onRegister: { glassesManager.register() })
                }
                
                // Video preview
                VideoPreviewSection(
                    frame: glassesManager.currentFrame,
                    isStreaming: glassesManager.connectionState == .streaming
                )
                
                // Controls
                ControlsSection(
                    state: glassesManager.connectionState,
                    isRegistered: glassesManager.isRegistered,
                    onConnect: { glassesManager.startSearching() },
                    onDisconnect: { glassesManager.disconnect() },
                    onStartStream: { glassesManager.startStreaming() },
                    onStopStream: { glassesManager.stopStreaming() },
                    onCapturePhoto: { glassesManager.capturePhoto() }
                )
                
                // Photo preview
                if let photoData = glassesManager.lastCapturedPhoto,
                   let uiImage = UIImage(data: photoData) {
                    PhotoPreviewSection(image: uiImage)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("AI Glasses")
        }
    }
}

// MARK: - Status Section

private struct StatusSection: View {
    let state: GlassesConnectionState
    let isRegistered: Bool
    let deviceCount: Int
    
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
                Label(isRegistered ? "Registered" : "Not Registered", 
                      systemImage: isRegistered ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.caption)
                    .foregroundColor(isRegistered ? .green : .orange)
                
                Label("\(deviceCount) device(s)", systemImage: "glasses")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        case .searching, .connecting:
            return .orange
        case .connected:
            return .blue
        case .streaming:
            return .green
        case .error:
            return .red
        }
    }
}

// MARK: - Registration Section

private struct RegistrationSection: View {
    let onRegister: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Register with Meta AI app to access glasses")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onRegister) {
                Label("Register App", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Video Preview Section

private struct VideoPreviewSection: View {
    let frame: VideoFrame?
    let isStreaming: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
            
            if isStreaming {
                if let frame = frame {
                    VideoFrameView(frame: frame)
                        .cornerRadius(16)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No video stream")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Video Frame View

private struct VideoFrameView: View {
    let frame: VideoFrame
    
    var body: some View {
        // Convert VideoFrame to displayable image
        if let uiImage = frame.makeUIImage() {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Color.black
        }
    }
}

// MARK: - Controls Section

private struct ControlsSection: View {
    let state: GlassesConnectionState
    let isRegistered: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onStartStream: () -> Void
    let onStopStream: () -> Void
    let onCapturePhoto: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Connection button
            if state.isConnected {
                Button(action: onDisconnect) {
                    Label("Disconnect", systemImage: "wifi.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button(action: onConnect) {
                    Label("Connect to Glasses", systemImage: "wifi")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(state == .searching || state == .connecting || !isRegistered)
            }
            
            // Streaming controls
            if state.isConnected {
                HStack(spacing: 16) {
                    if state == .streaming {
                        Button(action: onStopStream) {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        
                        Button(action: onCapturePhoto) {
                            Label("Photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(action: onStartStream) {
                            Label("Start Streaming", systemImage: "video.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}

// MARK: - Photo Preview Section

private struct PhotoPreviewSection: View {
    let image: UIImage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Captured Photo")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 120)
                .cornerRadius(8)
        }
    }
}

#Preview {
    ContentView()
}
