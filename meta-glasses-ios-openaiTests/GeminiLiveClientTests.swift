//
//  GeminiLiveClientTests.swift
//  meta-glasses-ios-openaiTests
//
//  Tests for Gemini Live API client functionality
//

import Testing
import Foundation
@testable import meta_glasses_ios_openai

// MARK: - Gemini Live State Tests

struct GeminiLiveStateTests {

    @Test func disconnectedStateProperties() {
        let state = GeminiLiveState.disconnected

        #expect(!state.isConnected)
    }

    @Test func connectingStateProperties() {
        let state = GeminiLiveState.connecting

        #expect(!state.isConnected)
    }

    @Test func connectedStateProperties() {
        let state = GeminiLiveState.connected

        #expect(state.isConnected)
    }

    @Test func streamingStateProperties() {
        let state = GeminiLiveState.streaming

        #expect(state.isConnected)
    }

    @Test func errorStateProperties() {
        let state = GeminiLiveState.error("Connection failed")

        #expect(!state.isConnected)
    }

    @Test func stateEquality() {
        #expect(GeminiLiveState.disconnected == GeminiLiveState.disconnected)
        #expect(GeminiLiveState.connecting == GeminiLiveState.connecting)
        #expect(GeminiLiveState.connected == GeminiLiveState.connected)
        #expect(GeminiLiveState.streaming == GeminiLiveState.streaming)
        #expect(GeminiLiveState.error("a") == GeminiLiveState.error("a"))
        #expect(GeminiLiveState.error("a") != GeminiLiveState.error("b"))
        #expect(GeminiLiveState.connected != GeminiLiveState.streaming)
    }
}

// MARK: - Gemini Live Error Tests

struct GeminiLiveErrorTests {

    @Test func noAPIKeyError() {
        let error = GeminiLiveError.noAPIKey

        #expect(error.errorDescription?.contains("API key") == true)
        #expect(error.errorDescription?.contains("Settings") == true)
    }

    @Test func invalidURLError() {
        let error = GeminiLiveError.invalidURL

        #expect(error.errorDescription?.contains("URL") == true)
    }

    @Test func notConnectedError() {
        let error = GeminiLiveError.notConnected

        #expect(error.errorDescription?.contains("connected") == true)
    }

    @Test func encodingError() {
        let error = GeminiLiveError.encodingError

        #expect(error.errorDescription?.contains("encode") == true)
    }

    @Test func connectionFailedError() {
        let error = GeminiLiveError.connectionFailed("Timeout")

        #expect(error.errorDescription?.contains("Timeout") == true)
        #expect(error.errorDescription?.contains("failed") == true)
    }

    @Test func allErrorsHaveDescriptions() {
        let errors: [GeminiLiveError] = [
            .noAPIKey,
            .invalidURL,
            .notConnected,
            .encodingError,
            .connectionFailed("test")
        ]

        for error in errors {
            #expect(error.errorDescription != nil, "Error \(error) should have a description")
            #expect(!error.errorDescription!.isEmpty, "Error \(error) description should not be empty")
        }
    }
}

// MARK: - Gemini Live Client Tests

struct GeminiLiveClientTests {

    @Test @MainActor func clientInitialState() {
        let client = GeminiLiveClient()

        #expect(client.state == .disconnected)
        #expect(client.lastTranscript.isEmpty)
    }

    @Test @MainActor func clientCallbacksCanBeSet() {
        let client = GeminiLiveClient()

        var audioReceived = false
        var textReceived = false
        var errorReceived = false

        client.onAudioReceived = { _ in audioReceived = true }
        client.onTextReceived = { _ in textReceived = true }
        client.onError = { _ in errorReceived = true }

        // Callbacks are set (we can't easily trigger them without a real connection)
        #expect(client.onAudioReceived != nil)
        #expect(client.onTextReceived != nil)
        #expect(client.onError != nil)
    }

    @Test @MainActor func disconnectFromDisconnectedState() {
        let client = GeminiLiveClient()

        // Should not crash when disconnecting from already disconnected state
        client.disconnect()

        #expect(client.state == .disconnected)
    }

    @Test @MainActor func stopVideoStreamWhenNotStreaming() {
        let client = GeminiLiveClient()

        // Should not crash when stopping video stream that isn't running
        client.stopVideoStream()

        #expect(client.state == .disconnected)
    }
}

// MARK: - Constants Tests

struct GeminiConstantsTests {

    @Test func geminiLiveAPIURLIsValid() {
        let url = Constants.geminiLiveAPIURL

        #expect(url.hasPrefix("wss://"))
        #expect(url.contains("generativelanguage.googleapis.com"))
        #expect(url.contains("BidiGenerateContent"))
    }

    @Test func geminiLiveModelIsSet() {
        let model = Constants.geminiLiveModel

        #expect(!model.isEmpty)
        #expect(model.contains("gemini"))
    }
}
