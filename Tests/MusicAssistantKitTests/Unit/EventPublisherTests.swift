// ABOUTME: Unit tests for EventPublisher Combine-based event routing
// ABOUTME: Validates event distribution to typed subjects and raw event stream

import Combine
import Foundation
@testable import MusicAssistantKit
import Testing

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

        await publisher.publish(event)
        await Task.yield() // Allow MainActor to process

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

        await publisher.publish(event)
        await Task.yield() // Allow MainActor to process

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

        await publisher.publish(event)
        await Task.yield() // Allow MainActor to process

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
        await publisher.publish(Event(event: "player_updated", objectId: "p1", data: nil))
        await publisher.publish(Event(event: "queue_updated", objectId: "q1", data: nil))
        await publisher.publish(Event(event: "unknown_event", objectId: nil, data: nil))
        await Task.yield() // Allow MainActor to process

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
        await publisher.publish(event)
        await Task.yield() // Allow MainActor to process

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
        await publisher.publish(event)
        await Task.yield() // Allow MainActor to process

        #expect(receivedRawEvents.count == 1)
        #expect(receivedRawEvents[0].event == "server_status")

        cancellable.cancel()
    }

    @Test("Publishes media_item_added events to mediaItemUpdates subject")
    func publishesMediaItemAddedEvents() async {
        let publisher = EventPublisher()
        var receivedEvents: [MediaItemEvent] = []

        let cancellable = publisher.mediaItemUpdates.sink { event in
            receivedEvents.append(event)
        }

        let event = Event(
            event: "media_item_added",
            objectId: "track-123",
            data: AnyCodable(["media_type": "track", "name": "Test Track"])
        )

        await publisher.publish(event)
        await Task.yield() // Allow MainActor to process

        #expect(receivedEvents.count == 1)
        #expect(receivedEvents[0].action == .added)
        #expect(receivedEvents[0].itemId == "track-123")
        #expect(receivedEvents[0].mediaType == .track)

        cancellable.cancel()
    }

    @Test("Publishes media_item_updated events to mediaItemUpdates subject")
    func publishesMediaItemUpdatedEvents() async {
        let publisher = EventPublisher()
        var receivedEvents: [MediaItemEvent] = []

        let cancellable = publisher.mediaItemUpdates.sink { event in
            receivedEvents.append(event)
        }

        let event = Event(
            event: "media_item_updated",
            objectId: "artist-456",
            data: AnyCodable(["media_type": "artist", "name": "Updated Artist"])
        )

        await publisher.publish(event)
        await Task.yield() // Allow MainActor to process

        #expect(receivedEvents.count == 1)
        #expect(receivedEvents[0].action == .updated)
        #expect(receivedEvents[0].itemId == "artist-456")
        #expect(receivedEvents[0].mediaType == .artist)

        cancellable.cancel()
    }

    @Test("Publishes media_item_deleted events to mediaItemUpdates subject")
    func publishesMediaItemDeletedEvents() async {
        let publisher = EventPublisher()
        var receivedEvents: [MediaItemEvent] = []

        let cancellable = publisher.mediaItemUpdates.sink { event in
            receivedEvents.append(event)
        }

        let event = Event(
            event: "media_item_deleted",
            objectId: "album-789",
            data: AnyCodable(["media_type": "album"])
        )

        await publisher.publish(event)
        await Task.yield() // Allow MainActor to process

        #expect(receivedEvents.count == 1)
        #expect(receivedEvents[0].action == .deleted)
        #expect(receivedEvents[0].itemId == "album-789")
        #expect(receivedEvents[0].mediaType == .album)

        cancellable.cancel()
    }

    @Test("Publishes media_item_played events to mediaItemUpdates subject")
    func publishesMediaItemPlayedEvents() async {
        let publisher = EventPublisher()
        var receivedEvents: [MediaItemEvent] = []

        let cancellable = publisher.mediaItemUpdates.sink { event in
            receivedEvents.append(event)
        }

        let event = Event(
            event: "media_item_played",
            objectId: "track-999",
            data: AnyCodable(["media_type": "track", "timestamp": 1_234_567_890])
        )

        await publisher.publish(event)
        await Task.yield() // Allow MainActor to process

        #expect(receivedEvents.count == 1)
        #expect(receivedEvents[0].action == .played)
        #expect(receivedEvents[0].itemId == "track-999")
        #expect(receivedEvents[0].mediaType == .track)

        cancellable.cancel()
    }

    @Test("Handles media item events with unknown media type")
    func handlesMediaItemEventsWithUnknownMediaType() async {
        let publisher = EventPublisher()
        var receivedEvents: [MediaItemEvent] = []

        let cancellable = publisher.mediaItemUpdates.sink { event in
            receivedEvents.append(event)
        }

        let event = Event(
            event: "media_item_added",
            objectId: "item-123",
            data: AnyCodable(["media_type": "podcast", "name": "Test Podcast"])
        )

        await publisher.publish(event)
        await Task.yield() // Allow MainActor to process

        #expect(receivedEvents.count == 1)
        #expect(receivedEvents[0].mediaType == .unknown)

        cancellable.cancel()
    }
}
