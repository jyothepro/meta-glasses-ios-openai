//
//  Constants.swift
//  ai-glasses
//
//  App-wide constants (non-secret values)
//

import Foundation

enum Constants {
    // MARK: - API URLs
    
    /// OpenAI Realtime API WebSocket endpoint
    static let realtimeAPIURL = "wss://api.openai.com/v1/realtime?model=gpt-realtime"
    
    /// OpenAI Chat Completions API endpoint
    static let openAIChatCompletionsURL = "https://api.openai.com/v1/chat/completions"
    
    /// Perplexity Search API endpoint
    static let perplexitySearchURL = "https://api.perplexity.ai/search"
    
    // MARK: - OpenAI Models
    
    /// Fast model for quick tasks (intent classification, title generation, etc.)
    static let fastModel = "gpt-4o-mini"
    
    /// Whisper model for audio transcription
    static let whisperModel = "whisper-1"
    
    // MARK: - Realtime API Settings
    
    /// Voice for Realtime API responses
    static let realtimeVoice = "marin"
}
