// ABOUTME: Tests for stream URL construction helper methods on MusicAssistantClient
// ABOUTME: Validates URL building for various stream endpoint types

@testable import MusicAssistantKit
import XCTest

final class StreamURLHelpersTests: XCTestCase {
    func testGetStreamURLFromMediaPath() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        // Connect to populate server info
        try await client.connect()

        let streamURL = try await client.getStreamURL(mediaPath: "flow/session123/queue456/item789.mp3")

        XCTAssertEqual(
            streamURL.url.absoluteString,
            "http://localhost:8095/flow/session123/queue456/item789.mp3"
        )
    }

    func testGetStreamURLThrowsWhenNotConnected() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        // Don't connect - should throw error
        do {
            _ = try await client.getStreamURL(mediaPath: "flow/test.mp3")
            XCTFail("Expected error when not connected")
        } catch MusicAssistantError.notConnected {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testConstructQueueStreamURL() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        try await client.connect()

        let streamURL = try await client.constructQueueStreamURL(
            sessionId: "session123",
            queueId: "queue456",
            queueItemId: "item789",
            format: .flac,
            flowMode: false
        )

        XCTAssertEqual(
            streamURL.url.absoluteString,
            "http://localhost:8095/single/session123/queue456/item789.flac"
        )
    }

    func testConstructQueueStreamURLFlowMode() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        try await client.connect()

        let streamURL = try await client.constructQueueStreamURL(
            sessionId: "session123",
            queueId: "queue456",
            queueItemId: "item789",
            format: .mp3,
            flowMode: true
        )

        XCTAssertEqual(
            streamURL.url.absoluteString,
            "http://localhost:8095/flow/session123/queue456/item789.mp3"
        )
    }

    func testConstructPreviewURL() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        try await client.connect()

        let streamURL = try await client.constructPreviewURL(
            itemId: "track123",
            provider: "library"
        )

        XCTAssertTrue(streamURL.url.absoluteString.contains("/preview?"))
        XCTAssertTrue(streamURL.url.absoluteString.contains("item_id="))
        XCTAssertTrue(streamURL.url.absoluteString.contains("provider=library"))
    }

    func testConstructAnnouncementURL() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        try await client.connect()

        let streamURL = try await client.constructAnnouncementURL(
            playerId: "player1",
            format: .mp3,
            preAnnounce: true
        )

        XCTAssertTrue(streamURL.url.absoluteString.contains("/announcement/player1.mp3"))
        XCTAssertTrue(streamURL.url.absoluteString.contains("pre_announce=true"))
    }

    func testConstructPluginSourceURL() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        try await client.connect()

        let streamURL = try await client.constructPluginSourceURL(
            pluginSource: "airplay",
            playerId: "player1",
            format: .flac
        )

        XCTAssertEqual(
            streamURL.url.absoluteString,
            "http://localhost:8095/pluginsource/airplay/player1.flac"
        )
    }
}
