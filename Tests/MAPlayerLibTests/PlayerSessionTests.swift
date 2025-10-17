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

        let session = try await PlayerSession(
            host: "192.168.23.196",
            port: 8095,
            playerId: "test-player",
            audioPlayer: mockPlayer
        )

        // Create a test event with a valid media path
        let testEvent = BuiltinPlayerEvent(
            command: .playMedia,
            mediaUrl: "flow/session/test-queue/test-item.mp3",
            queueId: "test-queue",
            queueItemId: "test-item"
        )

        // Handle the event
        await session.handleStreamEvent(testEvent)

        // Verify the audio player received the expected calls
        let lastURL = await mockPlayer.lastReplacedURL
        let playCallCount = await mockPlayer.playCallCount

        XCTAssertNotNil(lastURL, "Audio player should have received a URL")
        XCTAssertEqual(playCallCount, 1, "Audio player should have been told to play")

        // Verify the URL contains the expected media path
        if let url = lastURL {
            XCTAssertTrue(
                url.absoluteString.contains("test-queue"),
                "URL should contain the queue ID from the event"
            )
        }
    }
}
