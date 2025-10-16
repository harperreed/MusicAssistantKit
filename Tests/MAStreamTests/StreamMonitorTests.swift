// ABOUTME: Unit tests for StreamMonitor event subscription and URL extraction
// ABOUTME: Uses MockWebSocketConnection to simulate BUILTIN_PLAYER events

import XCTest
import Combine
@testable import MAStream
@testable import MusicAssistantKit
@testable import MusicAssistantKitTests

final class StreamMonitorTests: XCTestCase {
    func testMonitorReceivesEvents() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)
        try await client.connect()

        let monitor = StreamMonitor(client: client, testURLs: false)

        let expectation = expectation(description: "Receive stream event")

        let task = Task {
            var receivedURL: String?
            for await streamInfo in monitor.streamEvents {
                receivedURL = streamInfo.url
                expectation.fulfill()
                return receivedURL
            }
            return nil
        }

        // Give the stream time to set up before sending the event
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Simulate BUILTIN_PLAYER event
        await mockConnection.simulateBuiltinPlayerEvent(
            command: "PLAY_MEDIA",
            mediaUrl: "flow/session123/queue456/item789.mp3",
            queueId: "queue456",
            queueItemId: "item789"
        )

        await fulfillment(of: [expectation], timeout: 1.0)

        let receivedURL = await task.value
        XCTAssertNotNil(receivedURL)
        XCTAssertTrue(receivedURL!.contains("flow/session123/queue456/item789.mp3"))
    }
}
