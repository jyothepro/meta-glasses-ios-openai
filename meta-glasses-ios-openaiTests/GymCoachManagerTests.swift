//
//  GymCoachManagerTests.swift
//  meta-glasses-ios-openaiTests
//
//  Tests for AI gym coaching functionality
//

import Testing
import Foundation
@testable import meta_glasses_ios_openai

// MARK: - Coaching State Tests

struct CoachingStateTests {

    @Test func idleStateProperties() {
        let state = CoachingState.idle

        #expect(state.displayText == "Ready to coach")
        #expect(!state.isActive)
        #expect(state.currentExercise == nil)
    }

    @Test func startingStateProperties() {
        let state = CoachingState.starting

        #expect(state.displayText == "Starting coaching...")
        #expect(!state.isActive)
        #expect(state.currentExercise == nil)
    }

    @Test func activeStateProperties() {
        let state = CoachingState.active(exercise: "Bicep Curl")

        #expect(state.displayText == "Coaching: Bicep Curl")
        #expect(state.isActive)
        #expect(state.currentExercise == "Bicep Curl")
    }

    @Test func analyzingStateProperties() {
        let state = CoachingState.analyzing

        #expect(state.displayText == "Analyzing form...")
        #expect(state.isActive)
        #expect(state.currentExercise == nil)
    }

    @Test func errorStateProperties() {
        let state = CoachingState.error("Connection failed")

        #expect(state.displayText == "Error: Connection failed")
        #expect(!state.isActive)
        #expect(state.currentExercise == nil)
    }

    @Test func stateEquality() {
        #expect(CoachingState.idle == CoachingState.idle)
        #expect(CoachingState.analyzing == CoachingState.analyzing)
        #expect(CoachingState.active(exercise: "Squat") == CoachingState.active(exercise: "Squat"))
        #expect(CoachingState.active(exercise: "Squat") != CoachingState.active(exercise: "Deadlift"))
        #expect(CoachingState.error("a") == CoachingState.error("a"))
        #expect(CoachingState.error("a") != CoachingState.error("b"))
    }
}

// MARK: - Exercise Tests

struct ExerciseTests {

    @Test func exerciseCategoryRawValues() {
        #expect(Exercise.ExerciseCategory.arms.rawValue == "Arms")
        #expect(Exercise.ExerciseCategory.chest.rawValue == "Chest")
        #expect(Exercise.ExerciseCategory.back.rawValue == "Back")
        #expect(Exercise.ExerciseCategory.shoulders.rawValue == "Shoulders")
        #expect(Exercise.ExerciseCategory.legs.rawValue == "Legs")
        #expect(Exercise.ExerciseCategory.core.rawValue == "Core")
        #expect(Exercise.ExerciseCategory.fullBody.rawValue == "Full Body")
    }

    @Test func exerciseCategoryAllCases() {
        #expect(Exercise.ExerciseCategory.allCases.count == 7)
    }

    @Test func exerciseInitialization() {
        let exercise = Exercise(
            id: "test_exercise",
            name: "Test Exercise",
            category: .arms,
            formCues: ["Cue 1", "Cue 2"],
            commonMistakes: ["Mistake 1"],
            musclesWorked: ["Biceps", "Triceps"]
        )

        #expect(exercise.id == "test_exercise")
        #expect(exercise.name == "Test Exercise")
        #expect(exercise.category == .arms)
        #expect(exercise.formCues.count == 2)
        #expect(exercise.commonMistakes.count == 1)
        #expect(exercise.musclesWorked.count == 2)
    }
}

// MARK: - Coaching Feedback Tests

struct CoachingFeedbackTests {

    @Test func feedbackInitialization() {
        let feedback = CoachingFeedback(
            timestamp: Date(),
            exercise: "Squat",
            analysis: "Good depth! Keep your chest up.",
            formScore: 8,
            corrections: ["Keep chest up"],
            encouragement: "Good depth!"
        )

        #expect(feedback.exercise == "Squat")
        #expect(feedback.analysis == "Good depth! Keep your chest up.")
        #expect(feedback.formScore == 8)
        #expect(feedback.corrections.count == 1)
        #expect(feedback.encouragement == "Good depth!")
    }

    @Test func feedbackWithoutScore() {
        let feedback = CoachingFeedback(
            timestamp: Date(),
            exercise: "Plank",
            analysis: "Hold steady.",
            formScore: nil,
            corrections: [],
            encouragement: nil
        )

        #expect(feedback.formScore == nil)
        #expect(feedback.encouragement == nil)
        #expect(feedback.corrections.isEmpty)
    }
}

// MARK: - Coaching Error Tests

struct CoachingErrorTests {

    @Test func noAPIKeyError() {
        let error = CoachingError.noAPIKey

        #expect(error.errorDescription?.contains("API key") == true)
    }

    @Test func imageConversionError() {
        let error = CoachingError.imageConversionFailed

        #expect(error.errorDescription?.contains("image") == true)
    }

    @Test func networkError() {
        let error = CoachingError.networkError

        #expect(error.errorDescription?.contains("Network") == true)
    }

    @Test func apiError() {
        let error = CoachingError.apiError(401)

        #expect(error.errorDescription?.contains("401") == true)
    }

    @Test func parseError() {
        let error = CoachingError.parseError

        #expect(error.errorDescription?.contains("parse") == true)
    }

    @Test func noActiveSessionError() {
        let error = CoachingError.noActiveSession

        #expect(error.errorDescription?.contains("session") == true)
    }
}

// MARK: - Exercise Library Tests

struct ExerciseLibraryTests {

    @Test @MainActor func libraryContainsExpectedExercises() {
        let manager = GymCoachManager.shared
        let exercises = manager.exercises

        // Should have multiple exercises loaded
        #expect(exercises.count >= 10)

        // Check for key exercises
        let exerciseNames = exercises.map { $0.name.lowercased() }
        #expect(exerciseNames.contains("bicep curl"))
        #expect(exerciseNames.contains("squat"))
        #expect(exerciseNames.contains("bench press"))
        #expect(exerciseNames.contains("deadlift"))
        #expect(exerciseNames.contains("plank"))
    }

    @Test @MainActor func exerciseLookupByName() {
        let manager = GymCoachManager.shared

        // Exact match
        let squat = manager.getExercise(named: "Squat")
        #expect(squat != nil)
        #expect(squat?.name == "Squat")

        // Case insensitive
        let bicepCurl = manager.getExercise(named: "BICEP CURL")
        #expect(bicepCurl != nil)

        // Non-existent
        let nonExistent = manager.getExercise(named: "Imaginary Exercise")
        #expect(nonExistent == nil)
    }

    @Test @MainActor func allExercisesHaveFormCues() {
        let manager = GymCoachManager.shared

        for exercise in manager.exercises {
            #expect(!exercise.formCues.isEmpty, "Exercise '\(exercise.name)' should have form cues")
            #expect(!exercise.commonMistakes.isEmpty, "Exercise '\(exercise.name)' should have common mistakes")
            #expect(!exercise.musclesWorked.isEmpty, "Exercise '\(exercise.name)' should have muscles worked")
        }
    }

    @Test @MainActor func exercisesHaveUniqueIds() {
        let manager = GymCoachManager.shared
        let ids = manager.exercises.map { $0.id }
        let uniqueIds = Set(ids)

        #expect(ids.count == uniqueIds.count, "All exercises should have unique IDs")
    }

    @Test @MainActor func exercisesCoverAllCategories() {
        let manager = GymCoachManager.shared

        let categories = Set(manager.exercises.map { $0.category })

        // Should cover at least arms, chest, back, shoulders, legs, core
        #expect(categories.contains(.arms))
        #expect(categories.contains(.chest))
        #expect(categories.contains(.back))
        #expect(categories.contains(.shoulders))
        #expect(categories.contains(.legs))
        #expect(categories.contains(.core))
    }
}

// MARK: - Manager Settings Tests

struct GymCoachManagerSettingsTests {

    @Test @MainActor func defaultFrameInterval() {
        let manager = GymCoachManager.shared

        // Default should be 5 seconds
        #expect(manager.frameInterval == 5.0)
    }

    @Test @MainActor func defaultSpeakFeedback() {
        let manager = GymCoachManager.shared

        // Should speak feedback by default
        #expect(manager.speakFeedback == true)
    }

    @Test @MainActor func initialStateIsIdle() {
        let manager = GymCoachManager.shared

        // If no coaching session, state should be idle
        if !manager.state.isActive {
            #expect(manager.state == .idle)
        }
    }
}
