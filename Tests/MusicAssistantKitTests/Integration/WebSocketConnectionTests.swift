// ABOUTME: Integration tests for WebSocketConnection actor against real Music Assistant server
// ABOUTME: Uses MA_TEST_HOST and MA_TEST_PORT environment variables for server configuration

import Foundation
@testable import MusicAssistantKit
import Testing

@Suite("WebSocket Connection Integration Tests")
struct WebSocketConnectionTests {
    let testHost = ProcessInfo.processInfo.environment["MA_TEST_HOST"] ?? "localhost"
    let testPort = Int(ProcessInfo.processInfo.environment["MA_TEST_PORT"] ?? "8095") ?? 8095
    let skipIntegration = ProcessInfo.processInfo.environment["SKIP_INTEGRATION_TESTS"] != nil

    @Test(
        "Connect to Music Assistant server",
        .enabled(if: ProcessInfo.processInfo.environment["SKIP_INTEGRATION_TESTS"] == nil)
    )
    func connect() async throws {
        let connection = WebSocketConnection(host: testHost, port: testPort)

        try await connection.connect()

        let state = await connection.state
        #expect(state.isConnected, "Should be connected")

        await connection.disconnect()
    }
}
