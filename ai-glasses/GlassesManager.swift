//
//  GlassesManager.swift
//  ai-glasses
//
//  Created by Kirill Markin on 03/01/2026.
//

import Foundation
import Combine
import MWDATCore
import MWDATCamera

// MARK: - Connection State

enum GlassesConnectionState: Equatable {
    case disconnected
    case searching
    case connecting
    case connected
    case streaming
    case error(String)
    
    var displayText: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .searching:
            return "Searching..."
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .streaming:
            return "Streaming"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var isConnected: Bool {
        switch self {
        case .connected, .streaming:
            return true
        default:
            return false
        }
    }
}

// MARK: - Glasses Manager

@MainActor
final class GlassesManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var connectionState: GlassesConnectionState = .disconnected
    @Published private(set) var availableDevices: [DeviceIdentifier] = []
    @Published private(set) var currentFrame: VideoFrame?
    @Published private(set) var lastCapturedPhoto: Data?
    
    // MARK: - Private Properties
    
    private let wearables: WearablesInterface
    private var deviceSelector: AutoDeviceSelector?
    private var streamSession: StreamSession?
    
    // Listener tokens - must be retained to keep subscriptions active
    private var devicesListenerToken: AnyListenerToken?
    private var videoFrameListenerToken: AnyListenerToken?
    private var photoListenerToken: AnyListenerToken?
    private var errorListenerToken: AnyListenerToken?
    private var stateListenerToken: AnyListenerToken?
    
    // MARK: - Initialization
    
    init() {
        self.wearables = Wearables.shared
        setupDevicesListener()
    }
    
    // MARK: - Public Methods
    
    func startSearching() {
        connectionState = .searching
        deviceSelector = AutoDeviceSelector(wearables: wearables)
        
        Task {
            for await device in deviceSelector!.activeDeviceStream() {
                if device != nil {
                    connectionState = .connected
                    break
                }
            }
        }
    }
    
    func stopSearching() {
        deviceSelector = nil
        connectionState = .disconnected
    }
    
    func startStreaming() {
        guard let selector = deviceSelector else {
            connectionState = .error("No device selector available")
            return
        }
        
        // Use default config: raw video, medium resolution, 30 FPS
        let config = StreamSessionConfig()
        
        streamSession = StreamSession(
            streamSessionConfig: config,
            deviceSelector: selector
        )
        
        subscribeToStreamSession()
        
        Task {
            await streamSession?.start()
            connectionState = .streaming
        }
    }
    
    func stopStreaming() {
        Task {
            await streamSession?.stop()
            streamSession = nil
            currentFrame = nil
            await cancelStreamListeners()
            
            if deviceSelector?.activeDevice != nil {
                connectionState = .connected
            } else {
                connectionState = .disconnected
            }
        }
    }
    
    func capturePhoto() {
        streamSession?.capturePhoto(format: .jpeg)
    }
    
    func disconnect() {
        Task {
            await streamSession?.stop()
            streamSession = nil
            currentFrame = nil
            await cancelStreamListeners()
            deviceSelector = nil
            connectionState = .disconnected
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDevicesListener() {
        devicesListenerToken = wearables.addDevicesListener { [weak self] devices in
            guard let self else { return }
            Task { @MainActor in
                self.availableDevices = devices
            }
        }
    }
    
    private func subscribeToStreamSession() {
        guard let session = streamSession else { return }
        
        // Subscribe to video frames
        videoFrameListenerToken = session.videoFramePublisher.listen { [weak self] (frame: VideoFrame) in
            guard let self else { return }
            Task { @MainActor in
                self.currentFrame = frame
            }
        }
        
        // Subscribe to photos
        photoListenerToken = session.photoDataPublisher.listen { [weak self] (photoData: PhotoData) in
            guard let self else { return }
            Task { @MainActor in
                self.lastCapturedPhoto = photoData.data
            }
        }
        
        // Subscribe to errors
        errorListenerToken = session.errorPublisher.listen { [weak self] (error: StreamSessionError) in
            guard let self else { return }
            Task { @MainActor in
                self.connectionState = .error(error.localizedDescription)
            }
        }
        
        // Subscribe to state changes
        stateListenerToken = session.statePublisher.listen { [weak self] (state: StreamSessionState) in
            guard let self else { return }
            Task { @MainActor in
                self.handleStreamState(state)
            }
        }
    }
    
    private func cancelStreamListeners() async {
        await videoFrameListenerToken?.cancel()
        await photoListenerToken?.cancel()
        await errorListenerToken?.cancel()
        await stateListenerToken?.cancel()
        
        videoFrameListenerToken = nil
        photoListenerToken = nil
        errorListenerToken = nil
        stateListenerToken = nil
    }
    
    private func handleStreamState(_ state: StreamSessionState) {
        switch state {
        case .stopped:
            if deviceSelector?.activeDevice != nil {
                connectionState = .connected
            } else {
                connectionState = .disconnected
            }
        case .waitingForDevice:
            connectionState = .searching
        case .streaming:
            connectionState = .streaming
        case .starting:
            connectionState = .connecting
        case .stopping:
            connectionState = .connecting
        case .paused:
            connectionState = .connected
        @unknown default:
            break
        }
    }
}
