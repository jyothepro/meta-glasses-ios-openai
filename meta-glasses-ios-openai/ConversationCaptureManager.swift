//
//  ConversationCaptureManager.swift
//  meta-glasses-ios-openai
//
//  Orchestrates the conversation capture lifecycle:
//  idle → recording → processing → completed
//

import Foundation
import AVFoundation
import Combine
import UIKit
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta-glasses-ios-openai", category: "CaptureManager")

@MainActor
final class ConversationCaptureManager: ObservableObject {
    static let shared = ConversationCaptureManager()

    // MARK: - Published State

    @Published private(set) var captureState: CaptureState = .idle
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var audioSource: AudioSource = .deviceMic
    @Published private(set) var currentSession: CaptureSession?
    @Published private(set) var processingStep: String = ""

    // MARK: - Private

    private let audioManager = AudioManager()
    private let store = CaptureStore.shared
    private var elapsedTimer: AnyCancellable?
    private var meterTimer: AnyCancellable?
    private var routeChangeObserver: NSObjectProtocol?

    private init() {
        observeAudioRouteChanges()
    }

    // MARK: - Start Capture

    func startCapture() {
        guard captureState == .idle else {
            logger.warning("Cannot start capture: state is \(String(describing: self.captureState))")
            return
        }

        // Check microphone permission
        guard PermissionsManager.shared.microphoneStatus == .authorized else {
            captureState = .error("Microphone permission required")
            return
        }

        do {
            // Configure and start recording
            try audioManager.configureForHFP()

            // Detect audio source
            audioSource = detectAudioSource()

            // Create session
            let sessionId = UUID()
            _ = store.captureDirectory(for: sessionId)

            // Start recording
            _ = try audioManager.startRecording()

            // Enable metering for audio level
            audioManager.enableMetering()

            let session = CaptureSession(
                id: sessionId,
                createdAt: Date(),
                updatedAt: Date(),
                title: CaptureSession.defaultTitle(date: Date()),
                audioFilePath: "captures/\(sessionId.uuidString)/audio.m4a",
                audioSource: audioSource,
                location: LocationManager.shared.locationString
            )

            currentSession = session
            store.save(session)

            // Prevent screen sleep
            UIApplication.shared.isIdleTimerDisabled = true

            // Start elapsed timer
            elapsedTime = 0
            elapsedTimer = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self else { return }
                    self.elapsedTime = self.audioManager.recordingDuration
                }

            // Start audio level metering
            meterTimer = Timer.publish(every: 0.1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self else { return }
                    self.audioLevel = self.audioManager.currentAudioLevel()
                }

            captureState = .recording

            // Play start sound
            SoundManager.shared.playCaptureStartSound()

            logger.info("Capture started: \(sessionId) via \(self.audioSource.displayName)")

        } catch {
            captureState = .error("Failed to start recording: \(error.localizedDescription)")
            logger.error("Failed to start capture: \(error.localizedDescription)")
        }
    }

    // MARK: - Stop Capture

    func stopCapture() {
        guard captureState == .recording else {
            logger.warning("Cannot stop capture: not recording")
            return
        }

        do {
            let recordedURL = try audioManager.stopRecording()
            let duration = elapsedTime

            // Stop timers
            elapsedTimer?.cancel()
            elapsedTimer = nil
            meterTimer?.cancel()
            meterTimer = nil
            audioLevel = 0

            // Re-enable screen sleep
            UIApplication.shared.isIdleTimerDisabled = false

            // Play stop sound
            SoundManager.shared.playCaptureStopSound()

            // Move audio file to capture directory
            if var session = currentSession {
                let targetURL = store.audioFileURL(for: session.id)

                if recordedURL != targetURL {
                    let fm = FileManager.default
                    if fm.fileExists(atPath: targetURL.path) {
                        try? fm.removeItem(at: targetURL)
                    }
                    try fm.moveItem(at: recordedURL, to: targetURL)
                }

                session.duration = duration
                session.updatedAt = Date()
                currentSession = session
                store.save(session)

                logger.info("Capture stopped: \(session.id), duration: \(duration)s")
            }

            // Transition to processing and start pipeline
            captureState = .processing
            processingStep = "Transcribing..."

            Task {
                await runPostCapturePipeline()
            }

        } catch {
            captureState = .error("Failed to stop recording: \(error.localizedDescription)")
            logger.error("Failed to stop capture: \(error.localizedDescription)")
        }
    }

    // MARK: - Post-Capture Pipeline

    private func runPostCapturePipeline() async {
        guard var session = currentSession else { return }

        let audioURL = store.audioFileURL(for: session.id)

        // Step 1: Transcribe
        processingStep = "Transcribing..."
        session.transcriptStatus = .inProgress
        session.updatedAt = Date()
        currentSession = session
        store.save(session)

        do {
            let transcript = try await WhisperAPIClient.shared.transcribe(
                audioFileURL: audioURL,
                captureId: session.id
            )

            store.saveTranscript(transcript, for: session.id)
            session.transcriptStatus = .completed
            session.wordCount = transcript.fullText.split(separator: " ").count
            session.updatedAt = Date()
            currentSession = session
            store.save(session)

            logger.info("Transcription complete: \(session.wordCount) words")

            // Step 2: Generate title
            processingStep = "Generating title..."
            if let title = await generateTitle(transcript: transcript) {
                session.title = title
                session.updatedAt = Date()
                currentSession = session
                store.save(session)
            }

            // Step 3: Generate summary (if auto-summary enabled)
            if SettingsManager.shared.captureAutoSummary {
                processingStep = "Summarizing..."
                session.summaryStatus = .inProgress
                session.updatedAt = Date()
                currentSession = session
                store.save(session)

                do {
                    let summary = try await generateSummary(transcript: transcript, captureId: session.id)
                    store.saveSummary(summary, for: session.id)
                    session.summaryStatus = .completed
                    session.updatedAt = Date()
                    currentSession = session
                    store.save(session)
                    logger.info("Summary generation complete")
                } catch {
                    session.summaryStatus = .failed
                    session.updatedAt = Date()
                    currentSession = session
                    store.save(session)
                    logger.error("Summary generation failed: \(error.localizedDescription)")
                    // Don't fail the whole pipeline — transcript is still available
                }
            }

            processingStep = ""
            captureState = .completed
            logger.info("Capture pipeline complete: \(session.id)")

        } catch {
            session.transcriptStatus = .failed
            session.updatedAt = Date()
            currentSession = session
            store.save(session)
            processingStep = ""
            captureState = .error("Transcription failed: \(error.localizedDescription)")
            logger.error("Transcription failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Retry

    func retryTranscription() {
        guard let session = currentSession,
              session.transcriptStatus == .failed else { return }

        captureState = .processing
        Task {
            await runPostCapturePipeline()
        }
    }

    func retrySummary() {
        guard var session = currentSession,
              session.summaryStatus == .failed,
              session.transcriptStatus == .completed else { return }

        guard let transcript = store.loadTranscript(for: session.id) else { return }

        captureState = .processing
        processingStep = "Summarizing..."
        session.summaryStatus = .inProgress
        currentSession = session
        store.save(session)

        Task {
            do {
                let summary = try await generateSummary(transcript: transcript, captureId: session.id)
                store.saveSummary(summary, for: session.id)
                session.summaryStatus = .completed
                session.updatedAt = Date()
                currentSession = session
                store.save(session)
                processingStep = ""
                captureState = .completed
            } catch {
                session.summaryStatus = .failed
                session.updatedAt = Date()
                currentSession = session
                store.save(session)
                processingStep = ""
                captureState = .error("Summary failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cancel Capture

    func cancelCapture() {
        guard captureState == .recording else {
            logger.warning("Cannot cancel capture: not recording")
            return
        }

        audioManager.cancelRecording()

        // Stop timers
        elapsedTimer?.cancel()
        elapsedTimer = nil
        meterTimer?.cancel()
        meterTimer = nil
        audioLevel = 0

        // Re-enable screen sleep
        UIApplication.shared.isIdleTimerDisabled = false

        // Delete capture directory if session exists
        if let session = currentSession {
            store.delete(id: session.id)
        }

        currentSession = nil
        elapsedTime = 0
        captureState = .idle

        logger.info("Capture cancelled")
    }

    /// Set the current session (for retry from detail view)
    func setSession(_ session: CaptureSession) {
        currentSession = session
    }

    // MARK: - Reset to Idle

    func resetToIdle() {
        currentSession = nil
        elapsedTime = 0
        audioLevel = 0
        processingStep = ""
        captureState = .idle
    }

    // MARK: - Audio Source Detection

    private func detectAudioSource() -> AudioSource {
        if audioManager.isBluetoothInputAvailable() {
            return .glasses
        }
        return .deviceMic
    }

    func refreshAudioSource() {
        audioSource = detectAudioSource()
    }

    // MARK: - Audio Route Change Handling

    private func observeAudioRouteChanges() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self, self.captureState == .recording else { return }

                let previousSource = self.audioSource
                self.audioSource = self.detectAudioSource()

                if previousSource != self.audioSource {
                    logger.warning("Audio source changed during recording: \(previousSource.displayName) → \(self.audioSource.displayName)")
                }
            }
        }
    }

    // MARK: - Title Generation

    private func generateTitle(transcript: Transcript) async -> String? {
        let textSample = String(transcript.fullText.prefix(2000))

        let prompt = """
        Generate a title for this conversation (4 words max).
        Use the SAME LANGUAGE as the conversation.
        Only the essence - specific topic/subject discussed.
        Use SHORT words. No generic words like "discussion", "chat", "meeting".
        Return ONLY the title, no quotes, no explanation.

        Conversation transcript:
        \(textSample)
        """

        return await callFastModel(prompt: prompt)
    }

    // MARK: - Summary Generation

    private func generateSummary(transcript: Transcript, captureId: UUID) async throws -> CaptureSummary {
        let apiKey = SettingsManager.shared.openAIAPIKey
        guard !apiKey.isEmpty else {
            throw WhisperAPIError.noAPIKey
        }

        let textSample = String(transcript.fullText.prefix(12000))

        let prompt = """
        Analyze this conversation transcript and return a JSON object with:
        {
          "keyPoints": ["string array of key discussion points"],
          "decisions": ["string array of decisions made"],
          "actionItems": [{"description": "task", "assignee": "person or null", "deadline": "date or null"}],
          "topics": ["string array of topic tags"],
          "sentiment": "overall tone (e.g., positive, neutral, constructive)"
        }

        Rules:
        - Be concise. Each key point/decision should be one sentence.
        - Only include action items that were explicitly discussed.
        - If no decisions/action items, use empty arrays.
        - Topics should be 1-3 word tags.
        - Return ONLY valid JSON, no markdown.

        Transcript:
        \(textSample)
        """

        let url = URL(string: Constants.openAIChatCompletionsURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": Constants.fastModel,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_completion_tokens": 1000,
            "temperature": 0.3,
            "response_format": ["type": "json_object"]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            APIDebugLogger.shared.logChatCompletion(
                model: Constants.fastModel,
                prompt: "Summary generation",
                response: nil,
                statusCode: code,
                durationMs: durationMs,
                error: "HTTP \(code)"
            )
            throw WhisperAPIError.httpError(code, "Summary API error")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw WhisperAPIError.invalidResponse
        }

        APIDebugLogger.shared.logChatCompletion(
            model: Constants.fastModel,
            prompt: "Summary generation (\(transcript.fullText.count) chars)",
            response: String(content.prefix(200)),
            statusCode: 200,
            durationMs: durationMs
        )

        // Parse the JSON response
        guard let summaryData = content.data(using: .utf8),
              let summaryJSON = try JSONSerialization.jsonObject(with: summaryData) as? [String: Any] else {
            throw WhisperAPIError.invalidResponse
        }

        let keyPoints = summaryJSON["keyPoints"] as? [String] ?? []
        let decisions = summaryJSON["decisions"] as? [String] ?? []
        let topics = summaryJSON["topics"] as? [String] ?? []
        let sentiment = summaryJSON["sentiment"] as? String

        let actionItemsRaw = summaryJSON["actionItems"] as? [[String: Any]] ?? []
        let actionItems = actionItemsRaw.map { item in
            ActionItem(
                description: item["description"] as? String ?? "",
                assignee: item["assignee"] as? String,
                deadline: item["deadline"] as? String
            )
        }

        return CaptureSummary(
            captureId: captureId,
            keyPoints: keyPoints,
            decisions: decisions,
            actionItems: actionItems,
            sentiment: sentiment,
            topics: topics
        )
    }

    // MARK: - Fast Model Helper

    private func callFastModel(prompt: String) async -> String? {
        let apiKey = SettingsManager.shared.openAIAPIKey
        guard !apiKey.isEmpty else { return nil }

        let url = URL(string: Constants.openAIChatCompletionsURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": Constants.fastModel,
            "messages": [["role": "user", "content": prompt]],
            "max_completion_tokens": 30,
            "temperature": 0.3
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                return nil
            }

            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            logger.error("Fast model call failed: \(error.localizedDescription)")
            return nil
        }
    }

    deinit {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
