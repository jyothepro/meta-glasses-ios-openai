# Priorities Report - Example

This is an example priorities report. The nightly auto-compound job reads from reports in this directory and implements the highest priority item.

## How to Use

1. Create a new file named `priorities-YYYYMMDD.md` with your prioritized tasks
2. The auto-compound job will pick the #1 item and implement it
3. After implementation, move completed items to a "Done" section or remove them

---

## High Priority

1. **Add error retry logic for OpenAI WebSocket disconnections**: The RealtimeAPIClient should automatically reconnect when the WebSocket connection drops unexpectedly. This improves reliability during voice sessions.

2. **Implement conversation export feature**: Allow users to export their conversation history to text or JSON format from the Threads tab. Useful for reviewing or sharing conversations.

## Medium Priority

3. **Add haptic feedback for voice interactions**: Provide subtle haptic feedback when the AI starts/stops speaking, helping users know when to talk without looking at the screen.

4. **Optimize image capture quality settings**: Review and tune the photo capture settings for better quality when using the glasses camera during conversations.

5. **Add voice activity indicator animation**: Improve the visual feedback in VoiceAgentView to show audio levels while the user is speaking.

## Low Priority

6. **Add unit tests for ThreadsManager**: Improve test coverage for the conversation persistence layer.

7. **Document API rate limits and error codes**: Add documentation for common OpenAI API errors and rate limits.

---

## Done

- ~~Set up basic voice agent functionality~~
- ~~Implement glasses camera integration~~
