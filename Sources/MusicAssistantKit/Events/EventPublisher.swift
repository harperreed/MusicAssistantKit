// ABOUTME: Combine-based event publishing system routing server events to typed subjects
// ABOUTME: Provides type-safe event streams for player updates, queue updates, and raw events

import Foundation
import Combine

public class EventPublisher {
    public let playerUpdates = PassthroughSubject<PlayerUpdateEvent, Never>()
    public let queueUpdates = PassthroughSubject<QueueUpdateEvent, Never>()
    public let rawEvents = PassthroughSubject<Event, Never>()

    public init() {}

    public func publish(_ event: Event) {
        // Always publish raw event
        rawEvents.send(event)

        // Route to specific subjects based on event type
        switch event.event {
        case "player_updated":
            if let objectId = event.objectId,
               let data = event.data {
                let playerEvent = PlayerUpdateEvent(playerId: objectId, data: data)
                playerUpdates.send(playerEvent)
            }

        case "queue_updated", "queue_items_updated":
            if let objectId = event.objectId,
               let data = event.data {
                let queueEvent = QueueUpdateEvent(queueId: objectId, data: data)
                queueUpdates.send(queueEvent)
            }

        default:
            // Other events are only published as raw events
            break
        }
    }
}
