//
//  GymCoachManager.swift
//  meta-glasses-ios-openai
//
//  AI-powered gym coach that analyzes exercise form through Meta glasses camera
//

import Foundation
import UIKit
import AVFoundation
import Combine
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta-glasses-ios-openai", category: "GymCoachManager")

// MARK: - Coaching State

enum CoachingState: Equatable {
    case idle
    case starting
    case active(exercise: String)
    case analyzing
    case error(String)

    var isActive: Bool {
        if case .active = self { return true }
        if case .analyzing = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .idle:
            return "Ready to coach"
        case .starting:
            return "Starting coaching..."
        case .active(let exercise):
            return "Coaching: \(exercise)"
        case .analyzing:
            return "Analyzing form..."
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var currentExercise: String? {
        if case .active(let exercise) = self {
            return exercise
        }
        return nil
    }
}

// MARK: - Exercise Definition

struct Exercise: Identifiable, Codable {
    let id: String
    let name: String
    let category: ExerciseCategory
    let formCues: [String]
    let commonMistakes: [String]
    let musclesWorked: [String]

    enum ExerciseCategory: String, Codable, CaseIterable {
        case arms = "Arms"
        case chest = "Chest"
        case back = "Back"
        case shoulders = "Shoulders"
        case legs = "Legs"
        case core = "Core"
        case fullBody = "Full Body"
    }
}

// MARK: - Coaching Feedback

struct CoachingFeedback {
    let timestamp: Date
    let exercise: String
    let analysis: String
    let formScore: Int? // 1-10 if detectable
    let corrections: [String]
    let encouragement: String?
}

// MARK: - Gym Coach Manager

@MainActor
final class GymCoachManager: ObservableObject {

    // MARK: - Singleton

    static let shared = GymCoachManager()

    // MARK: - Published State

    @Published private(set) var state: CoachingState = .idle
    @Published private(set) var currentFeedback: CoachingFeedback?
    @Published private(set) var sessionFeedbackHistory: [CoachingFeedback] = []
    @Published private(set) var repCount: Int = 0
    @Published var frameInterval: TimeInterval = 5.0 // Seconds between analysis
    @Published var speakFeedback: Bool = true

    // MARK: - Private Properties

    private var analysisTimer: Timer?
    private var sessionStartTime: Date?
    private var lastFrameAnalysisTime: Date?
    private var frameProvider: (() -> UIImage?)?
    private var speechCallback: ((String) -> Void)?

    // TTS
    private let speechSynthesizer = AVSpeechSynthesizer()

    // Exercise library
    private(set) var exercises: [Exercise] = []

    // MARK: - Initialization

    private init() {
        loadExerciseLibrary()
    }

    // MARK: - Public Methods

    /// Start a coaching session for the given exercise
    func startCoaching(
        exercise: String,
        frameProvider: @escaping () -> UIImage?,
        speechCallback: ((String) -> Void)? = nil
    ) {
        guard !state.isActive else {
            logger.warning("Coaching already active")
            return
        }

        logger.info("🏋️ Starting coaching for: \(exercise)")
        state = .starting

        self.frameProvider = frameProvider
        self.speechCallback = speechCallback
        sessionStartTime = Date()
        sessionFeedbackHistory = []
        repCount = 0

        // Normalize exercise name
        let normalizedExercise = normalizeExerciseName(exercise)

        state = .active(exercise: normalizedExercise)

        // Give initial instructions
        let exerciseInfo = getExerciseInfo(normalizedExercise)
        let greeting = "Starting \(normalizedExercise) coaching. \(exerciseInfo.initialTip) I'll analyze your form every \(Int(frameInterval)) seconds."
        speak(greeting)

        // Start periodic analysis
        startAnalysisTimer()

        logger.info("🏋️ Coaching active for: \(normalizedExercise)")
    }

    /// Stop the current coaching session
    func stopCoaching() {
        guard state.isActive else { return }

        logger.info("🏋️ Stopping coaching session")

        analysisTimer?.invalidate()
        analysisTimer = nil

        // Give session summary
        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            let minutes = Int(duration) / 60
            let summary = "Coaching session ended. Duration: \(minutes) minutes. \(sessionFeedbackHistory.count) form checks completed."
            speak(summary)
        }

        state = .idle
        frameProvider = nil
        speechCallback = nil
        sessionStartTime = nil
    }

    /// Manually trigger a form check
    func checkFormNow() {
        guard state.isActive else { return }
        analyzeCurrentFrame()
    }

    /// Increment rep count (can be called by voice or detected)
    func incrementRep() {
        repCount += 1
        logger.info("🏋️ Rep count: \(self.repCount)")
    }

    /// Get exercise info for a given exercise name
    func getExercise(named name: String) -> Exercise? {
        let normalized = normalizeExerciseName(name)
        return exercises.first { normalizeExerciseName($0.name) == normalized }
    }

    // MARK: - Private Methods

    private func startAnalysisTimer() {
        analysisTimer?.invalidate()
        analysisTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.analyzeCurrentFrame()
            }
        }
    }

    private func analyzeCurrentFrame() {
        guard case .active(let exercise) = state else { return }
        guard let frameProvider = frameProvider,
              let frame = frameProvider() else {
            logger.warning("🏋️ No frame available for analysis")
            return
        }

        // Prevent overlapping analyses
        guard state != .analyzing else { return }

        let previousState = state
        state = .analyzing
        lastFrameAnalysisTime = Date()

        Task {
            do {
                let feedback = try await analyzeFrame(frame, exercise: exercise)
                await MainActor.run {
                    self.currentFeedback = feedback
                    self.sessionFeedbackHistory.append(feedback)
                    self.state = previousState

                    // Speak feedback if enabled
                    if self.speakFeedback {
                        self.speakFeedback(feedback)
                    }
                }
            } catch {
                await MainActor.run {
                    self.state = previousState
                    logger.error("🏋️ Analysis error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func analyzeFrame(_ image: UIImage, exercise: String) async throws -> CoachingFeedback {
        // Get API key
        let apiKey = await MainActor.run { SettingsManager.shared.openAIAPIKey }
        guard !apiKey.isEmpty else {
            throw CoachingError.noAPIKey
        }

        // Get exercise-specific prompt
        let exerciseInfo = getExerciseInfo(exercise)
        let prompt = buildAnalysisPrompt(exercise: exercise, info: exerciseInfo)

        // Convert image to base64 (high quality for accurate form analysis)
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw CoachingError.imageConversionFailed
        }
        let base64Image = imageData.base64EncodedString()

        // Call GPT-4o Vision API
        let response = try await callVisionAPI(
            apiKey: apiKey,
            prompt: prompt,
            imageBase64: base64Image
        )

        // Parse response into feedback
        return parseAnalysisResponse(response, exercise: exercise)
    }

    private func buildAnalysisPrompt(exercise: String, info: ExerciseInfo) -> String {
        return """
        You are an expert fitness coach watching a user perform \(exercise) through their smart glasses.
        The image shows their reflection in a gym mirror.

        **CRITICAL: Analyze ONLY what you actually SEE in this specific image.**

        Look at the user's CURRENT body position and tell them:
        1. What you observe about their form RIGHT NOW (be specific - mention body parts, angles, positions)
        2. ONE specific adjustment they should make based on what you see
        3. If their form looks good, tell them exactly what they're doing well

        **Be extremely specific.** Instead of generic advice, describe what you actually see:
        - BAD: "Keep your back straight" (generic)
        - GOOD: "I see your lower back rounding - squeeze your core and think about sticking your chest out"

        - BAD: "Good form" (too vague)
        - GOOD: "Your elbow position is perfect, staying right at your sides"

        - BAD: "Watch your knees" (generic)
        - GOOD: "Your left knee is caving inward a bit - push it out over your toe"

        **Response rules:**
        - 1-2 sentences MAX (this will be spoken aloud)
        - Describe what you SEE, not what they SHOULD do in general
        - Be encouraging but honest
        - If you can't see the relevant body parts clearly, say so
        - No bullet points, just natural speech

        Respond now based on what you see in this image:
        """
    }

    private func callVisionAPI(apiKey: String, prompt: String, imageBase64: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(imageBase64)",
                                "detail": "high" // Use high detail for accurate form analysis
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 150
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoachingError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("🏋️ Vision API error: \(httpResponse.statusCode) - \(errorBody)")
            throw CoachingError.apiError(httpResponse.statusCode)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw CoachingError.parseError
        }

        return content
    }

    private func parseAnalysisResponse(_ response: String, exercise: String) -> CoachingFeedback {
        // Extract corrections (sentences with corrective language)
        let corrections = response.components(separatedBy: ". ")
            .filter { sentence in
                let lower = sentence.lowercased()
                return lower.contains("try") ||
                       lower.contains("keep") ||
                       lower.contains("watch") ||
                       lower.contains("make sure") ||
                       lower.contains("remember")
            }
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // Check for encouragement
        let encouragement: String? = response.components(separatedBy: ". ")
            .first { sentence in
                let lower = sentence.lowercased()
                return lower.contains("good") ||
                       lower.contains("great") ||
                       lower.contains("excellent") ||
                       lower.contains("nice") ||
                       lower.contains("perfect")
            }

        return CoachingFeedback(
            timestamp: Date(),
            exercise: exercise,
            analysis: response,
            formScore: nil, // Could parse if we ask for it in prompt
            corrections: corrections,
            encouragement: encouragement
        )
    }

    private func speakFeedback(_ feedback: CoachingFeedback) {
        speak(feedback.analysis)
    }

    private func speak(_ text: String) {
        // Use callback if provided (for integration with RealtimeAPIClient)
        if let callback = speechCallback {
            callback(text)
            return
        }

        // Otherwise use local TTS
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = 1.0

        speechSynthesizer.speak(utterance)
    }

    // MARK: - Exercise Library

    private func loadExerciseLibrary() {
        exercises = [
            // Arms
            Exercise(
                id: "bicep_curl",
                name: "Bicep Curl",
                category: .arms,
                formCues: [
                    "Keep elbows pinned to your sides",
                    "Full range of motion - extend arms fully at bottom",
                    "Control the weight on the way down (eccentric)",
                    "Don't swing or use momentum"
                ],
                commonMistakes: [
                    "Swinging the weight using body momentum",
                    "Elbows drifting forward or backward",
                    "Not fully extending arms at the bottom",
                    "Rushing the negative portion"
                ],
                musclesWorked: ["Biceps", "Forearms"]
            ),
            Exercise(
                id: "tricep_pushdown",
                name: "Tricep Pushdown",
                category: .arms,
                formCues: [
                    "Keep elbows pinned at your sides",
                    "Only your forearms should move",
                    "Squeeze triceps at the bottom",
                    "Control the weight back up"
                ],
                commonMistakes: [
                    "Elbows flaring out",
                    "Leaning too far forward",
                    "Using shoulder muscles to push down",
                    "Not fully extending at the bottom"
                ],
                musclesWorked: ["Triceps"]
            ),

            // Chest
            Exercise(
                id: "bench_press",
                name: "Bench Press",
                category: .chest,
                formCues: [
                    "Retract shoulder blades and arch upper back slightly",
                    "Lower bar to mid-chest",
                    "Keep wrists straight over elbows",
                    "Drive feet into floor for stability"
                ],
                commonMistakes: [
                    "Bouncing bar off chest",
                    "Flaring elbows too wide (90 degrees)",
                    "Losing shoulder blade retraction",
                    "Uneven bar path"
                ],
                musclesWorked: ["Chest", "Triceps", "Front Deltoids"]
            ),
            Exercise(
                id: "push_up",
                name: "Push Up",
                category: .chest,
                formCues: [
                    "Keep body in straight line from head to heels",
                    "Hands slightly wider than shoulder width",
                    "Lower chest to just above the ground",
                    "Keep core tight throughout"
                ],
                commonMistakes: [
                    "Hips sagging or piking up",
                    "Not going low enough",
                    "Flaring elbows too wide",
                    "Head dropping forward"
                ],
                musclesWorked: ["Chest", "Triceps", "Core", "Shoulders"]
            ),

            // Back
            Exercise(
                id: "lat_pulldown",
                name: "Lat Pulldown",
                category: .back,
                formCues: [
                    "Pull bar to upper chest, not behind neck",
                    "Lead with elbows, squeeze shoulder blades",
                    "Lean back slightly (10-15 degrees)",
                    "Control the weight back up"
                ],
                commonMistakes: [
                    "Using momentum/swinging",
                    "Pulling bar behind neck",
                    "Not fully extending arms at top",
                    "Gripping too narrow or too wide"
                ],
                musclesWorked: ["Lats", "Biceps", "Rear Deltoids"]
            ),
            Exercise(
                id: "bent_over_row",
                name: "Bent Over Row",
                category: .back,
                formCues: [
                    "Keep back flat, hinge at hips",
                    "Pull elbows back, squeeze shoulder blades",
                    "Keep neck neutral (don't look up)",
                    "Control the weight down"
                ],
                commonMistakes: [
                    "Rounding the lower back",
                    "Standing too upright",
                    "Using momentum to swing weight",
                    "Not pulling high enough"
                ],
                musclesWorked: ["Lats", "Rhomboids", "Biceps", "Rear Deltoids"]
            ),

            // Shoulders
            Exercise(
                id: "shoulder_press",
                name: "Shoulder Press",
                category: .shoulders,
                formCues: [
                    "Press straight up, not forward",
                    "Keep core tight, don't arch back",
                    "Full lockout at the top",
                    "Lower to ear level or slightly below"
                ],
                commonMistakes: [
                    "Excessive back arch",
                    "Pressing the bar forward",
                    "Not locking out fully",
                    "Flaring elbows too wide"
                ],
                musclesWorked: ["Shoulders", "Triceps", "Upper Chest"]
            ),
            Exercise(
                id: "lateral_raise",
                name: "Lateral Raise",
                category: .shoulders,
                formCues: [
                    "Raise arms to shoulder height",
                    "Slight bend in elbows throughout",
                    "Lead with elbows, not hands",
                    "Control the descent"
                ],
                commonMistakes: [
                    "Using momentum/swinging",
                    "Raising too high (above shoulders)",
                    "Shrugging shoulders up",
                    "Hands higher than elbows"
                ],
                musclesWorked: ["Side Deltoids"]
            ),

            // Legs
            Exercise(
                id: "squat",
                name: "Squat",
                category: .legs,
                formCues: [
                    "Keep chest up and back straight",
                    "Push knees out over toes",
                    "Go to at least parallel (hip crease below knee)",
                    "Drive through heels to stand"
                ],
                commonMistakes: [
                    "Knees caving inward",
                    "Leaning too far forward",
                    "Not hitting proper depth",
                    "Heels coming off the ground"
                ],
                musclesWorked: ["Quadriceps", "Glutes", "Hamstrings", "Core"]
            ),
            Exercise(
                id: "deadlift",
                name: "Deadlift",
                category: .legs,
                formCues: [
                    "Keep bar close to body throughout",
                    "Hinge at hips, keep back flat",
                    "Drive through heels, squeeze glutes at top",
                    "Lower with control, hips back first"
                ],
                commonMistakes: [
                    "Rounding the lower back",
                    "Bar drifting away from body",
                    "Hyperextending at the top",
                    "Starting with hips too low (like a squat)"
                ],
                musclesWorked: ["Hamstrings", "Glutes", "Lower Back", "Traps"]
            ),
            Exercise(
                id: "lunge",
                name: "Lunge",
                category: .legs,
                formCues: [
                    "Keep torso upright",
                    "Front knee tracks over toes",
                    "Lower until back knee nearly touches ground",
                    "Push through front heel to return"
                ],
                commonMistakes: [
                    "Knee going past toes",
                    "Torso leaning forward",
                    "Not going deep enough",
                    "Losing balance side to side"
                ],
                musclesWorked: ["Quadriceps", "Glutes", "Hamstrings"]
            ),

            // Core
            Exercise(
                id: "plank",
                name: "Plank",
                category: .core,
                formCues: [
                    "Body in straight line from head to heels",
                    "Engage core - draw belly button in",
                    "Don't let hips sag or pike up",
                    "Keep breathing - don't hold breath"
                ],
                commonMistakes: [
                    "Hips sagging toward ground",
                    "Hips too high (piking)",
                    "Head dropping or looking up",
                    "Holding breath"
                ],
                musclesWorked: ["Core", "Shoulders", "Glutes"]
            ),
            Exercise(
                id: "crunch",
                name: "Crunch",
                category: .core,
                formCues: [
                    "Lift shoulder blades off ground",
                    "Keep lower back pressed to floor",
                    "Don't pull on neck with hands",
                    "Exhale as you crunch up"
                ],
                commonMistakes: [
                    "Pulling on neck",
                    "Using momentum",
                    "Coming up too high (full sit-up)",
                    "Feet coming off ground"
                ],
                musclesWorked: ["Abs"]
            )
        ]
    }

    private func normalizeExerciseName(_ name: String) -> String {
        return name
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }

    private struct ExerciseInfo {
        let formCues: [String]
        let commonMistakes: [String]
        let initialTip: String
    }

    private func getExerciseInfo(_ exerciseName: String) -> ExerciseInfo {
        let normalized = normalizeExerciseName(exerciseName)

        // Find matching exercise
        if let exercise = exercises.first(where: { normalizeExerciseName($0.name) == normalized }) {
            let tip = exercise.formCues.first ?? "Focus on controlled movements."
            return ExerciseInfo(
                formCues: exercise.formCues,
                commonMistakes: exercise.commonMistakes,
                initialTip: tip
            )
        }

        // Default for unknown exercises
        return ExerciseInfo(
            formCues: [
                "Maintain proper posture",
                "Control the movement",
                "Use full range of motion",
                "Keep core engaged"
            ],
            commonMistakes: [
                "Using momentum instead of muscle",
                "Poor posture",
                "Rushing through reps",
                "Not using full range of motion"
            ],
            initialTip: "Focus on controlled movements with good posture."
        )
    }
}

// MARK: - Errors

enum CoachingError: LocalizedError {
    case noAPIKey
    case imageConversionFailed
    case networkError
    case apiError(Int)
    case parseError
    case noActiveSession

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not configured"
        case .imageConversionFailed:
            return "Failed to convert image for analysis"
        case .networkError:
            return "Network error during analysis"
        case .apiError(let code):
            return "API error: \(code)"
        case .parseError:
            return "Failed to parse analysis response"
        case .noActiveSession:
            return "No active coaching session"
        }
    }
}
