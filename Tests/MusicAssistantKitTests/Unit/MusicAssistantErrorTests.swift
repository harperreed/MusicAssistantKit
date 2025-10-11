// ABOUTME: Unit tests for MusicAssistantError enum and error descriptions
// ABOUTME: Validates error messages and localized descriptions for all error cases

import Foundation
@testable import MusicAssistantKit
import Testing

@Suite("MusicAssistantError Unit Tests")
struct MusicAssistantErrorTests {

    @Test("notConnected error has correct description")
    func notConnectedDescription() {
        let error = MusicAssistantError.notConnected

        #expect(error.errorDescription == "Not connected to Music Assistant server")
    }

    @Test("connectionFailed error includes underlying error description")
    func connectionFailedDescription() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test connection error" }
        }
        let underlyingError = TestError()
        let error = MusicAssistantError.connectionFailed(underlying: underlyingError)

        let description = error.errorDescription
        #expect(description?.contains("Connection failed") == true)
        #expect(description?.contains("Test connection error") == true)
    }

    @Test("commandTimeout error includes message ID and timeout duration")
    func commandTimeoutDescription() {
        let error = MusicAssistantError.commandTimeout(messageId: 42)

        let description = error.errorDescription
        #expect(description?.contains("Command 42") == true)
        #expect(description?.contains("timed out") == true)
        #expect(description?.contains("30 seconds") == true)
    }

    @Test("serverError with code includes both code and message")
    func serverErrorWithCodeDescription() {
        let error = MusicAssistantError.serverError(
            code: 500,
            message: "Internal server error",
            details: nil
        )

        let description = error.errorDescription
        #expect(description?.contains("Server error 500") == true)
        #expect(description?.contains("Internal server error") == true)
    }

    @Test("serverError without code includes only message")
    func serverErrorWithoutCodeDescription() {
        let error = MusicAssistantError.serverError(
            code: nil,
            message: "Something went wrong",
            details: nil
        )

        let description = error.errorDescription
        #expect(description == "Server error: Something went wrong")
    }

    @Test("invalidResponse error has correct description")
    func invalidResponseDescription() {
        let error = MusicAssistantError.invalidResponse

        #expect(error.errorDescription == "Received invalid response from server")
    }

    @Test("decodingFailed error includes underlying error description")
    func decodingFailedDescription() {
        struct DecodingTestError: Error, LocalizedError {
            var errorDescription: String? { "Invalid JSON format" }
        }
        let underlyingError = DecodingTestError()
        let error = MusicAssistantError.decodingFailed(underlyingError)

        let description = error.errorDescription
        #expect(description?.contains("Failed to decode response") == true)
        #expect(description?.contains("Invalid JSON format") == true)
    }
}
