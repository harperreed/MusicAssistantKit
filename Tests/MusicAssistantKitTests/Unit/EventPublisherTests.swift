// ABOUTME: Unit tests for EventPublisher Combine-based event routing
// ABOUTME: Validates event distribution to typed subjects and raw event stream

import Foundation
import Testing
import Combine
@testable import MusicAssistantKit

@Suite("EventPublisher Unit Tests")
struct EventPublisherTests {

    @Test("Publishes player update events to playerUpdates subject")
    func publishesPlayerUpdateEvents() async {
        let publisher = EventPublisher()
        var receivedEvents: [PlayerUpdateEvent] = []

        let cancellable = publisher.playerUpdates.sink { event in
            receivedEvents.append(event)
        }

        let event = Event(
            event: "player_updated",
            objectId: "player-123",
            data: AnyCodable(["state": "playing", "volume": 75])
        )

        publisher.publish(event)

        // Give Combine a moment to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        #expect(receivedEvents.count == 1)
        #expect(receivedEvents[0].playerId == "player-123")

        cancellable.cancel()
    }

    @Test("Publishes queue update events to queueUpdates subject")
    func publishesQueueUpdateEvents() async {
        let publisher = EventPublisher()
        var receivedEvents: [QueueUpdateEvent] = []

        let cancellable = publisher.queueUpdates.sink { event in
            receivedEvents.append(event)
        }

        let event = Event(
            event: "queue_updated",
            objectId: "queue-456",
            data: AnyCodable(["shuffle": true])
        )

        publisher.publish(event)

        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(receivedEvents.count == 1)
        #expect(receivedEvents[0].queueId == "queue-456")

        cancellable.cancel()
    }

    @Test("Publishes queue_items_updated to queueUpdates subject")
    func publishesQueueItemsUpdatedEvents() async {
        let publisher = EventPublisher()
        var receivedEvents: [QueueUpdateEvent] = []

        let cancellable = publisher.queueUpdates.sink { event in
            receivedEvents.append(event)
        }

        let event = Event(
            event: "queue_items_updated",
            objectId: "queue-789",
            data: AnyCodable(["items": []])
        )

        publisher.publish(event)

        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(receivedEvents.count == 1)
        #expect(receivedEvents[0].queueId == "queue-789")

        cancellable.cancel()
    }

    @Test("Publishes all events to rawEvents subject")
    func publishesAllEventsToRawSubject() async {
        let publisher = EventPublisher()
        var receivedEvents: [Event] = []

        let cancellable = publisher.rawEvents.sink { event in
            receivedEvents.append(event)
        }

        // Publish different event types
        publisher.publish(Event(event: "player_updated", objectId: "p1", data: nil))
        publisher.publish(Event(event: "queue_updated", objectId: "q1", data: nil))
        publisher.publish(Event(event: "unknown_event", objectId: nil, data: nil))

        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(receivedEvents.count == 3)
        #expect(receivedEvents[0].event == "player_updated")
        #expect(receivedEvents[1].event == "queue_updated")
        #expect(receivedEvents[2].event == "unknown_event")

        cancellable.cancel()
    }

    @Test("Does not route unknown events to typed subjects")
    func doesNotRouteUnknownEventsToTypedSubjects() async {
        let publisher = EventPublisher()
        var playerEvents: [PlayerUpdateEvent] = []
        var queueEvents: [QueueUpdateEvent] = []

        let playerCancellable = publisher.playerUpdates.sink { playerEvents.append($0) }
        let queueCancellable = publisher.queueUpdates.sink { queueEvents.append($0) }

        let event = Event(event: "unknown_event", objectId: "test", data: nil)
        publisher.publish(event)

        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(playerEvents.isEmpty)
        #expect(queueEvents.isEmpty)

        playerCancellable.cancel()
        queueCancellable.cancel()
    }

    @Test("Handles events without objectId gracefully")
    func handlesEventsWithoutObjectId() async {
        let publisher = EventPublisher()
        var receivedRawEvents: [Event] = []

        let cancellable = publisher.rawEvents.sink { event in
            receivedRawEvents.append(event)
        }

        let event = Event(event: "server_status", objectId: nil, data: nil)
        publisher.publish(event)

        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(receivedRawEvents.count == 1)
        #expect(receivedRawEvents[0].event == "server_status")

        cancellable.cancel()
    }
}
