// ABOUTME: Combine-based event publishing system routing server events to typed subjects
// ABOUTME: Provides type-safe event streams for player updates, queue updates, and raw events

@preconcurrency import Combine
import Foundation

// Note: EventPublisher is @unchecked Sendable because PassthroughSubject doesn't conform to Sendable in older Combine
// versions
// The class is immutable after init and PassthroughSubject is thread-safe
public final class EventPublisher: @unchecked Sendable {
    public let playerUpdates = PassthroughSubject<PlayerUpdateEvent, Never>()
    public let queueUpdates = PassthroughSubject<QueueUpdateEvent, Never>()
    public let builtinPlayerEvents = PassthroughSubject<BuiltinPlayerEvent, Never>()
    public let rawEvents = PassthroughSubject<Event, Never>()

    public init() {}

    public func publish(_ event: Event) {
        // Always publish raw event
        rawEvents.send(event)

        // Route to specific subjects based on event type
        switch event.event {
        case "player_updated":
            if let objectId = event.objectId,
               let dataWrapper = event.data,
               let dataDict = dataWrapper.value as? [String: Any] {
                // Convert [String: Any] to [String: AnyCodable]
                let anyCodableDict = dataDict.mapValues { AnyCodable($0) }
                let playerEvent = PlayerUpdateEvent(playerId: objectId, data: anyCodableDict)
                playerUpdates.send(playerEvent)
            }

        case "queue_updated", "queue_items_updated":
            if let objectId = event.objectId,
               let dataWrapper = event.data,
               let dataDict = dataWrapper.value as? [String: Any] {
                // Convert [String: Any] to [String: AnyCodable]
                let anyCodableDict = dataDict.mapValues { AnyCodable($0) }
                let queueEvent = QueueUpdateEvent(queueId: objectId, data: anyCodableDict)
                queueUpdates.send(queueEvent)
            }

        case "BUILTIN_PLAYER":
            if let dataWrapper = event.data,
               let dataDict = dataWrapper.value as? [String: Any],
               let jsonData = try? JSONSerialization.data(withJSONObject: dataDict),
               let builtinEvent = try? JSONDecoder().decode(BuiltinPlayerEvent.self, from: jsonData) {
                builtinPlayerEvents.send(builtinEvent)
            }

        default:
            // Other events are only published as raw events
            break
        }
    }
}
