// ABOUTME: Tests for PlayerSession actor managing MusicAssistantClient and AVPlayer
// ABOUTME: Validates initialization, connection, and core session lifecycle

@testable import MAPlayerLib
import MusicAssistantKit
import XCTest

final class PlayerSessionTests: XCTestCase {
    func testInitializationConnectsToServer() async throws {
        let session = try await PlayerSession(
            host: "192.168.23.196",
            port: 8095,
            playerId: "test-player"
        )

        XCTAssertNotNil(session)
    }
}
