//
//  Constants.swift
//  meta-glasses-ios-openai
//
//  App-wide constants (non-secret values)
//

import Foundation

enum Constants {
    // MARK: - API URLs
    
    /// OpenAI Realtime API WebSocket endpoint
    static let realtimeAPIURL = "wss://api.openai.com/v1/realtime?model=gpt-realtime-mini"
    
    /// OpenAI Chat Completions API endpoint
    static let openAIChatCompletionsURL = "https://api.openai.com/v1/chat/completions"
    
    /// Perplexity Chat Completions API endpoint (used for web search)
    static let perplexitySearchURL = "https://api.perplexity.ai/chat/completions"

    /// OpenAI Whisper Transcription API endpoint
    static let whisperTranscriptionURL = "https://api.openai.com/v1/audio/transcriptions"
    
    // MARK: - OpenAI Models
    
    /// Fast model for quick tasks (intent classification, title generation, etc.)
    static let fastModel = "gpt-5.4-mini"
    
    /// Whisper model for audio transcription
    static let whisperModel = "whisper-1"
    
    // MARK: - Realtime API Settings

    /// Voice for Realtime API responses
    static let realtimeVoice = "coral"

    // MARK: - Google Gemini Settings

    /// Gemini Live API WebSocket endpoint
    static let geminiLiveAPIURL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"

    /// Gemini model for Live API (real-time audio + video)
    static let geminiLiveModel = "gemini-3.1-flash-lite-preview"
}
