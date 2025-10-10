// ABOUTME: Integration tests for WebSocketConnection actor against real Music Assistant server
// ABOUTME: Requires server running at 192.168.23.196:8095 for test execution

import XCTest
@testable import MusicAssistantKit

final class WebSocketConnectionTests: XCTestCase {
    let testHost = "192.168.23.196"
    let testPort = 8095

    func testConnect() async throws {
        let connection = WebSocketConnection(host: testHost, port: testPort)

        try await connection.connect()

        let state = await connection.state
        XCTAssertTrue(state.isConnected, "Should be connected")

        await connection.disconnect()
    }
}
