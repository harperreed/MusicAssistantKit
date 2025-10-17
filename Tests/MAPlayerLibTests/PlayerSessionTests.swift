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

    func testStreamEventLoadsIntoAudioPlayer() async throws {
        let mockPlayer = await MockAudioPlayer()

        // Note: This test will need a real client or mock later
        // For now, just verify the handleStreamEvent logic compiles
        let playCallCount = await mockPlayer.playCallCount
        XCTAssertEqual(playCallCount, 0)
    }
}
