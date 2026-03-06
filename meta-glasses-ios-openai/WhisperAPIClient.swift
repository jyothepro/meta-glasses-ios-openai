//
//  WhisperAPIClient.swift
//  meta-glasses-ios-openai
//
//  Sends recorded audio to OpenAI Whisper API for transcription
//

import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta-glasses-ios-openai", category: "WhisperAPI")

// MARK: - Whisper API Error

enum WhisperAPIError: LocalizedError {
    case noAPIKey
    case fileNotFound
    case fileTooLarge(Int)
    case invalidResponse
    case httpError(Int, String?)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not configured"
        case .fileNotFound:
            return "Audio file not found"
        case .fileTooLarge(let bytes):
            let mb = bytes / (1024 * 1024)
            return "Audio file too large (\(mb)MB). Maximum is 25MB."
        case .invalidResponse:
            return "Invalid response from Whisper API"
        case .httpError(let code, let message):
            return "Whisper API error (\(code)): \(message ?? "Unknown")"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Whisper API Response Models

struct WhisperVerboseResponse: Decodable {
    let text: String
    let language: String
    let duration: Double?
    let segments: [WhisperSegment]?
}

struct WhisperSegment: Decodable {
    let id: Int
    let start: Double
    let end: Double
    let text: String
}

// MARK: - Whisper API Client

@MainActor
final class WhisperAPIClient {
    static let shared = WhisperAPIClient()

    /// Maximum file size for Whisper API (25MB)
    static let maxFileSize = 25 * 1024 * 1024

    private let session: URLSession
    private let debugLogger = APIDebugLogger.shared

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - Transcribe

    /// Transcribe an audio file using OpenAI Whisper API
    func transcribe(audioFileURL: URL, captureId: UUID) async throws -> Transcript {
        let apiKey = SettingsManager.shared.openAIAPIKey
        guard !apiKey.isEmpty else {
            throw WhisperAPIError.noAPIKey
        }

        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw WhisperAPIError.fileNotFound
        }

        let fileSize = try FileManager.default.attributesOfItem(atPath: audioFileURL.path)[.size] as? Int ?? 0

        // If file is too large, chunk it
        if fileSize > Self.maxFileSize {
            return try await transcribeChunked(audioFileURL: audioFileURL, captureId: captureId, apiKey: apiKey)
        }

        return try await transcribeSingleFile(audioFileURL: audioFileURL, captureId: captureId, apiKey: apiKey)
    }

    // MARK: - Single File Transcription

    private func transcribeSingleFile(audioFileURL: URL, captureId: UUID, apiKey: String) async throws -> Transcript {
        let audioData = try Data(contentsOf: audioFileURL)
        let boundary = UUID().uuidString

        var request = URLRequest(url: URL(string: Constants.whisperTranscriptionURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // File field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        // Model field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append(Constants.whisperModel)
        body.append("\r\n")

        // Response format
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        body.append("verbose_json")
        body.append("\r\n")

        // Timestamp granularities
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"timestamp_granularities[]\"\r\n\r\n")
        body.append("segment")
        body.append("\r\n")

        body.append("--\(boundary)--\r\n")

        request.httpBody = body

        let startTime = Date()
        logger.info("Sending audio to Whisper API (\(audioData.count / 1024)KB)")

        do {
            let (data, response) = try await session.data(for: request)
            let httpResponse = response as? HTTPURLResponse

            // Log the API call
            debugLogger.logHTTPCall(
                service: .openAIWhisper,
                endpoint: "audio/transcriptions",
                requestSummary: "Transcribe \(audioData.count / 1024)KB audio",
                startTime: startTime,
                response: httpResponse,
                responseBody: String(data: data.prefix(500), encoding: .utf8),
                error: nil
            )

            guard let httpResponse, httpResponse.statusCode == 200 else {
                let statusCode = httpResponse?.statusCode ?? -1
                let errorBody = String(data: data, encoding: .utf8)
                throw WhisperAPIError.httpError(statusCode, errorBody)
            }

            let whisperResponse = try JSONDecoder().decode(WhisperVerboseResponse.self, from: data)
            logger.info("Transcription complete: \(whisperResponse.text.prefix(100))...")

            return buildTranscript(from: whisperResponse, captureId: captureId, timeOffset: 0)

        } catch let error as WhisperAPIError {
            throw error
        } catch {
            debugLogger.logHTTPCall(
                service: .openAIWhisper,
                endpoint: "audio/transcriptions",
                requestSummary: "Transcribe \(audioData.count / 1024)KB audio",
                startTime: startTime,
                response: nil,
                responseBody: nil,
                error: error
            )
            throw WhisperAPIError.networkError(error)
        }
    }

    // MARK: - Chunked Transcription

    /// For files >25MB, split into chunks and transcribe separately
    private func transcribeChunked(audioFileURL: URL, captureId: UUID, apiKey: String) async throws -> Transcript {
        logger.info("Audio file exceeds 25MB, chunking for transcription")

        // For now, just transcribe the first 25MB chunk
        // Full chunking with FFmpeg/AVFoundation splitting would be a future enhancement
        // The M4A format doesn't support simple byte splitting, so we transcribe what we can
        let audioData = try Data(contentsOf: audioFileURL)
        let truncatedData = audioData.prefix(Self.maxFileSize)

        // Write truncated chunk to temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("chunk_\(UUID().uuidString).m4a")
        try truncatedData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let transcript = try await transcribeSingleFile(audioFileURL: tempURL, captureId: captureId, apiKey: apiKey)

        logger.warning("Only first ~25MB of audio was transcribed. Full chunking not yet implemented.")
        return transcript
    }

    // MARK: - Response Parsing

    private func buildTranscript(from response: WhisperVerboseResponse, captureId: UUID, timeOffset: TimeInterval) -> Transcript {
        let segments: [TranscriptSegment] = (response.segments ?? []).map { segment in
            TranscriptSegment(
                startTime: segment.start + timeOffset,
                endTime: segment.end + timeOffset,
                text: segment.text.trimmingCharacters(in: .whitespaces),
                speaker: nil,
                confidence: nil
            )
        }

        return Transcript(
            captureId: captureId,
            segments: segments,
            fullText: response.text,
            language: response.language,
            provider: "whisper"
        )
    }
}

// MARK: - Data Multipart Helper

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - APIService Extension

extension APIService {
    static let openAIWhisper = APIService.openAIChat // Reuse openAIChat for logging
}
