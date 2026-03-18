# Changes Made
**Date:** March 17, 2026

## 1. Fixed Siri Shortcut Phrases
**File:** `meta-glasses-ios-openai/SiriIntents.swift`, `README.md`
- Added `\(.applicationName)` to "Start glasses mode" and "jyo mode" phrases — iOS requires every App Shortcut utterance to include `${applicationName}`

## 2. Replaced Perplexity with OpenAI for Web Search
**Files:** `Constants.swift`, `RealtimeAPIClient.swift`
- **Problem:** Perplexity API key quota exceeded, search_internet tool was failing
- **Fix:** Switched to OpenAI's `gpt-4o-mini-search-preview` model with `web_search_options` via Chat Completions API
- Endpoint changed from `https://api.perplexity.ai/search` → `https://api.openai.com/v1/chat/completions`
- search_internet tool is now always enabled (no longer conditional on Perplexity config)
- Uses existing OpenAI API key — no extra key needed

## 3. Fixed Intent Classifier Model Name
**File:** `Constants.swift`
- Changed `fastModel` from `gpt-5-mini` (invalid, returning 400 errors) to `gpt-5.4-mini`

## 4. Fixed Gym Coaching Stream Auto-Stop
**File:** `GlassesManager.swift`
- **Problem:** Video stream from glasses auto-stopped after 60s of inactivity even during active gym coaching
- **Fix:** Auto-stop timer now checks `GymCoachManager.shared.state.isActive` — won't stop stream while coaching is active

## 5. Updated Gemini Gym Coaching Model
**File:** `Constants.swift`
- Changed Gemini Live model from `gemini-2.5-flash-native-audio-latest` → `gemini-3.1-flash-lite-preview`

## Current Model Usage

| Feature | Model |
|---------|-------|
| Voice conversations | `gpt-realtime-mini` |
| Intent classifier | `gpt-5.4-mini` |
| Web search | `gpt-4o-mini-search-preview` |
| Gym coaching (OpenAI fallback) | `gpt-4o` |
| Gym coaching (Gemini) | `gemini-3.1-flash-lite-preview` |
| Thread titles | `gpt-5.4-mini` |
