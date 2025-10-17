// ABOUTME: Tests for built-in player event publishing through EventPublisher
// ABOUTME: Verifies BUILTIN_PLAYER events are correctly routed to subscribers

import Combine
@testable import MusicAssistantKit
import XCTest

final class BuiltinPlayerEventPublisherTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testBuiltinPlayerEventPublished() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        var receivedEvent: BuiltinPlayerEvent?
        let expectation = expectation(description: "Receive built-in player event")

        // Access events from within the actor
        let events = await client.events
        events.builtinPlayerEvents
            .sink { event in
                receivedEvent = event
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Connect to initialize the client
        try await client.connect()

        // Simulate BUILTIN_PLAYER event
        let event = Event(
            event: "BUILTIN_PLAYER",
            objectId: nil,
            data: AnyCodable([
                "command": "PLAY_MEDIA",
                "media_url": "flow/session123/queue456/item789.mp3",
                "queue_id": "queue456",
                "queue_item_id": "item789",
            ])
        )
        await mockConnection.simulateEvent(event)

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.command, .playMedia)
        XCTAssertEqual(receivedEvent?.mediaUrl, "flow/session123/queue456/item789.mp3")
        XCTAssertEqual(receivedEvent?.queueId, "queue456")
        XCTAssertEqual(receivedEvent?.queueItemId, "item789")
    }

    func testBuiltinPlayerStopEvent() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        var receivedEvent: BuiltinPlayerEvent?
        let expectation = expectation(description: "Receive stop event")

        let events = await client.events
        events.builtinPlayerEvents
            .sink { event in
                receivedEvent = event
                expectation.fulfill()
            }
            .store(in: &cancellables)

        try await client.connect()

        let event = Event(
            event: "BUILTIN_PLAYER",
            objectId: nil,
            data: AnyCodable([
                "command": "STOP",
            ])
        )
        await mockConnection.simulateEvent(event)

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.command, .stop)
        XCTAssertNil(receivedEvent?.mediaUrl)
    }

    func testBuiltinPlayerUnknownCommand() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        var receivedEvent: BuiltinPlayerEvent?
        let expectation = expectation(description: "Receive unknown command event")

        let events = await client.events
        events.builtinPlayerEvents
            .sink { event in
                receivedEvent = event
                expectation.fulfill()
            }
            .store(in: &cancellables)

        try await client.connect()

        let event = Event(
            event: "BUILTIN_PLAYER",
            objectId: nil,
            data: AnyCodable([
                "command": "SOME_NEW_COMMAND",
                "media_url": "test.mp3",
            ])
        )
        await mockConnection.simulateEvent(event)

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.command, .unknown)
        XCTAssertEqual(receivedEvent?.mediaUrl, "test.mp3")
    }

    func testNonBuiltinPlayerEventNotPublished() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        var receivedEvent: BuiltinPlayerEvent?

        let events = await client.events
        events.builtinPlayerEvents
            .sink { event in
                receivedEvent = event
            }
            .store(in: &cancellables)

        try await client.connect()

        // Simulate a different event type
        let event = Event(
            event: "player_updated",
            objectId: "player1",
            data: AnyCodable(["state": "playing"])
        )
        await mockConnection.simulateEvent(event)

        // Give it a moment to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        XCTAssertNil(receivedEvent, "Non-BUILTIN_PLAYER events should not be published")
    }

    func testMockBuiltinPlayerEventHelper() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        var receivedEvent: BuiltinPlayerEvent?
        let expectation = expectation(description: "Receive event via helper")

        let events = await client.events
        events.builtinPlayerEvents
            .sink { event in
                receivedEvent = event
                expectation.fulfill()
            }
            .store(in: &cancellables)

        try await client.connect()

        // Use the new helper method
        await mockConnection.simulateBuiltinPlayerEvent(
            command: "PLAY_MEDIA",
            mediaUrl: "flow/test/queue/item.mp3",
            queueId: "queue",
            queueItemId: "item"
        )

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.command, .playMedia)
        XCTAssertEqual(receivedEvent?.mediaUrl, "flow/test/queue/item.mp3")
        XCTAssertEqual(receivedEvent?.queueId, "queue")
        XCTAssertEqual(receivedEvent?.queueItemId, "item")
    }
}
