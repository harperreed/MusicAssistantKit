// ABOUTME: Integration tests for WebSocketConnection actor against real Music Assistant server
// ABOUTME: Uses MA_TEST_HOST and MA_TEST_PORT environment variables for server configuration

import Foundation
import Testing
@testable import MusicAssistantKit

@Suite("WebSocket Connection Integration Tests")
struct WebSocketConnectionTests {
    let testHost = ProcessInfo.processInfo.environment["MA_TEST_HOST"] ?? "localhost"
    let testPort = Int(ProcessInfo.processInfo.environment["MA_TEST_PORT"] ?? "8095") ?? 8095

    @Test("Connect to Music Assistant server")
    func connect() async throws {
        let connection = WebSocketConnection(host: testHost, port: testPort)

        try await connection.connect()

        let state = await connection.state
        #expect(state.isConnected, "Should be connected")

        await connection.disconnect()
    }
}
