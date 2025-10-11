// ABOUTME: Error types for Music Assistant client operations
// ABOUTME: Covers connection, command, and protocol-level failures

import Foundation

public enum MusicAssistantError: Error, LocalizedError {
    case notConnected
    case connectionFailed(underlying: Error)
    case commandTimeout(messageId: Int)
    case serverError(code: Int?, message: String, details: [String: AnyCodable]?)
    case invalidResponse
    case decodingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Music Assistant server"
        case let .connectionFailed(error):
            return "Connection failed: \(error.localizedDescription)"
        case let .commandTimeout(messageId):
            return "Command \(messageId) timed out after 30 seconds"
        case let .serverError(code, message, _):
            if let code {
                return "Server error \(code): \(message)"
            }
            return "Server error: \(message)"
        case .invalidResponse:
            return "Received invalid response from server"
        case let .decodingFailed(error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
