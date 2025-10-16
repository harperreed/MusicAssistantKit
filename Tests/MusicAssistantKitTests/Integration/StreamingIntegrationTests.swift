// ABOUTME: Integration tests for streaming audio URLs against live Music Assistant server
// ABOUTME: Tests BUILTIN_PLAYER event capture and stream URL accessibility

import XCTest
import Combine
@testable import MusicAssistantKit

final class StreamingIntegrationTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testStreamURLConstruction() async throws {
        // Skip if integration tests are disabled
        if ProcessInfo.processInfo.environment["SKIP_INTEGRATION_TESTS"] != nil {
            throw XCTSkip("Integration tests disabled")
        }

        let host = ProcessInfo.processInfo.environment["MA_TEST_HOST"] ?? "localhost"
        let port = Int(ProcessInfo.processInfo.environment["MA_TEST_PORT"] ?? "8095")!

        let client = MusicAssistantClient(host: host, port: port)
        try await client.connect()

        // Give server time to send ServerInfo
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        print("Testing stream URL construction with host=\(host), port=\(port)...")

        // Test that stream URL helper methods work with connected client
        let queueStreamURL = try await client.constructQueueStreamURL(
            sessionId: "test-session",
            queueId: "test-queue",
            queueItemId: "test-item",
            format: .mp3,
            flowMode: true
        )
        print("✓ Queue stream URL: \(queueStreamURL.url.absoluteString)")
        XCTAssertTrue(queueStreamURL.url.absoluteString.contains("/flow/"))
        XCTAssertTrue(queueStreamURL.url.absoluteString.contains("test-session"))
        XCTAssertTrue(queueStreamURL.url.absoluteString.contains("test-queue"))
        XCTAssertTrue(queueStreamURL.url.absoluteString.contains("test-item"))

        // Test preview URL construction
        let previewURL = try await client.constructPreviewURL(itemId: "test", provider: "library")
        print("✓ Preview URL: \(previewURL.url.absoluteString)")
        XCTAssertTrue(previewURL.url.absoluteString.contains("/preview?"))
        XCTAssertTrue(previewURL.url.absoluteString.contains("provider=library"))

        // Test announcement URL construction
        let announcementURL = try await client.constructAnnouncementURL(
            playerId: "player1",
            format: .mp3,
            preAnnounce: true
        )
        print("✓ Announcement URL: \(announcementURL.url.absoluteString)")
        XCTAssertTrue(announcementURL.url.absoluteString.contains("/announcement/"))
        XCTAssertTrue(announcementURL.url.absoluteString.contains("player1"))

        print("✓ All stream URL construction tests passed")

        await client.disconnect()
    }

    func testBuiltinPlayerEventSubscription() async throws {
        // Skip if integration tests are disabled
        if ProcessInfo.processInfo.environment["SKIP_INTEGRATION_TESTS"] != nil {
            throw XCTSkip("Integration tests disabled")
        }

        let host = ProcessInfo.processInfo.environment["MA_TEST_HOST"] ?? "localhost"
        let port = Int(ProcessInfo.processInfo.environment["MA_TEST_PORT"] ?? "8095")!

        let client = MusicAssistantClient(host: host, port: port)

        // Set up event listener before connecting
        var receivedEvent: BuiltinPlayerEvent?
        let expectation = expectation(description: "Receive built-in player event")

        let events = await client.events
        events.builtinPlayerEvents.sink { event in
            print("Received BUILTIN_PLAYER event: \(event.command)")
            if let mediaUrl = event.mediaUrl {
                print("  Media URL: \(mediaUrl)")
            }
            if receivedEvent == nil {
                receivedEvent = event
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        try await client.connect()

        // Subscribe to raw events to watch for BUILTIN_PLAYER
        events.rawEvents.sink { event in
            print("Raw event: \(event.event)")
        }.store(in: &cancellables)

        // Note: This test requires manual playback to trigger events
        // Wait for any BUILTIN_PLAYER event from the server
        let result = await XCTWaiter.fulfillment(of: [expectation], timeout: 30.0)

        if result == .completed {
            // We received an event!
            XCTAssertNotNil(receivedEvent)
            print("Successfully captured BUILTIN_PLAYER event")

            if let mediaUrl = receivedEvent?.mediaUrl {
                // Try to construct and verify the stream URL
                let streamURL = try await client.getStreamURL(mediaPath: mediaUrl)
                print("Full stream URL: \(streamURL.url.absoluteString)")

                // Try to access the URL (may fail if session expired)
                do {
                    let (_, response) = try await URLSession.shared.data(from: streamURL.url)
                    if let httpResponse = response as? HTTPURLResponse {
                        print("Stream URL response code: \(httpResponse.statusCode)")
                        // Don't assert on status code as stream may have expired
                    }
                } catch {
                    print("Stream URL access failed (may be expired): \(error)")
                }
            }
        } else {
            print("Note: No BUILTIN_PLAYER event received within timeout")
            print("To test event capture, start playback on a player connected to this server")
            throw XCTSkip("No BUILTIN_PLAYER event received (requires active playback)")
        }

        await client.disconnect()
    }
}
