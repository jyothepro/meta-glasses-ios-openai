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
import os.log

// MARK: - Logging

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ai-glasses", category: "GlassesManager")

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
    
    @Published private(set) var connectionState: GlassesConnectionState = .disconnected {
        didSet {
            if oldValue != connectionState {
                logger.info("🔄 State changed: \(oldValue.displayText) → \(self.connectionState.displayText)")
            }
        }
    }
    @Published private(set) var availableDevices: [DeviceIdentifier] = []
    @Published private(set) var currentFrame: VideoFrame?
    @Published private(set) var lastCapturedPhoto: Data?
    @Published private(set) var isRegistered: Bool = false
    
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
        logger.info("📱 GlassesManager initialized")
        self.wearables = Wearables.shared
        setupDevicesListener()
        setupRegistrationListener()
    }
    
    // MARK: - Public Methods
    
    func register() {
        if isRegistered {
            logger.info("📝 Already registered, skipping")
            return
        }
        logger.info("📝 Starting registration with Meta AI app...")
        do {
            try wearables.startRegistration()
            logger.info("✅ Registration started - check Meta AI app")
        } catch {
            logger.warning("⚠️ Registration request failed: \(error.localizedDescription)")
            // Don't set error state - registration might complete via callback
        }
    }
    
    func unregister() {
        logger.info("📝 Starting unregistration...")
        do {
            try wearables.startUnregistration()
            logger.info("✅ Unregistration started")
        } catch {
            logger.error("❌ Unregistration failed: \(error.localizedDescription)")
        }
    }
    
    func startSearching() {
        logger.info("🔍 Starting device search")
        connectionState = .searching
        deviceSelector = AutoDeviceSelector(wearables: wearables)
        
        Task {
            for await device in deviceSelector!.activeDeviceStream() {
                if let device = device {
                    logger.info("✅ Device found: \(String(describing: device))")
                    connectionState = .connected
                    break
                }
            }
        }
    }
    
    func stopSearching() {
        logger.info("⏹️ Stopping device search")
        deviceSelector = nil
        connectionState = .disconnected
    }
    
    func startStreaming() {
        logger.info("🎬 Starting streaming...")
        guard let selector = deviceSelector else {
            logger.error("❌ No device selector available")
            connectionState = .error("No device selector available")
            return
        }
        
        Task {
            // Check and request camera permission
            do {
                let cameraStatus = try await wearables.checkPermissionStatus(.camera)
                
                if cameraStatus != .granted {
                    logger.info("📷 Requesting camera permission...")
                    let newStatus = try await wearables.requestPermission(.camera)
                    
                    if newStatus != .granted {
                        logger.error("❌ Camera permission denied")
                        connectionState = .error("Camera permission denied")
                        return
                    }
                    logger.info("📷 Camera permission granted")
                }
            } catch {
                logger.error("❌ Camera permission error: \(error.localizedDescription)")
                connectionState = .error("Camera permission error: \(error.localizedDescription)")
                return
            }
            
            // Use default config: raw video, medium resolution, 30 FPS
            let config = StreamSessionConfig()
            
            streamSession = StreamSession(
                streamSessionConfig: config,
                deviceSelector: selector
            )
            
            subscribeToStreamSession()
            await streamSession?.start()
        }
    }
    
    func stopStreaming() {
        logger.info("⏹️ Stopping streaming")
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
        logger.info("📸 Capturing photo...")
        streamSession?.capturePhoto(format: .jpeg)
    }
    
    func disconnect() {
        logger.info("🔌 Disconnecting...")
        Task {
            await streamSession?.stop()
            streamSession = nil
            currentFrame = nil
            await cancelStreamListeners()
            deviceSelector = nil
            connectionState = .disconnected
            logger.info("✅ Disconnected")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDevicesListener() {
        devicesListenerToken = wearables.addDevicesListener { [weak self] devices in
            guard let self else { return }
            Task { @MainActor in
                if devices.count != self.availableDevices.count {
                    logger.info("📱 Devices: \(devices.count) available")
                }
                self.availableDevices = devices
            }
        }
    }
    
    private func setupRegistrationListener() {
        Task {
            for await state in wearables.registrationStateStream() {
                await MainActor.run {
                    let wasRegistered = self.isRegistered
                    // Check if state is .registered
                    if case .registered = state {
                        self.isRegistered = true
                        if !wasRegistered {
                            logger.info("✅ App is registered with Meta AI")
                        }
                    } else {
                        self.isRegistered = false
                        if wasRegistered {
                            logger.info("⚪ App unregistered: \(String(describing: state))")
                        }
                    }
                }
            }
        }
    }
    
    private func subscribeToStreamSession() {
        guard let session = streamSession else { return }
        
        // Track frame count for logging (not every frame)
        var frameCount = 0
        
        // Subscribe to video frames
        videoFrameListenerToken = session.videoFramePublisher.listen { [weak self] (frame: VideoFrame) in
            guard let self else { return }
            frameCount += 1
            // Log every 100th frame to avoid spam
            if frameCount == 1 || frameCount % 100 == 0 {
                logger.debug("🎞️ Frame #\(frameCount) received")
            }
            Task { @MainActor in
                self.currentFrame = frame
            }
        }
        
        // Subscribe to photos
        photoListenerToken = session.photoDataPublisher.listen { [weak self] (photoData: PhotoData) in
            guard let self else { return }
            logger.info("📸 Photo received: \(photoData.data.count) bytes")
            Task { @MainActor in
                self.lastCapturedPhoto = photoData.data
            }
        }
        
        // Subscribe to errors
        errorListenerToken = session.errorPublisher.listen { [weak self] (error: StreamSessionError) in
            guard let self else { return }
            logger.error("❌ Stream error: \(error.localizedDescription)")
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
            logger.info("🟢 Streaming started")
            connectionState = .streaming
        case .starting:
            connectionState = .connecting
        case .stopping:
            connectionState = .connecting
        case .paused:
            connectionState = .connected
        @unknown default:
            logger.warning("⚠️ Unknown stream state: \(String(describing: state))")
        }
    }
}
