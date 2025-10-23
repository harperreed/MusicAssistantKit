// ABOUTME: Combine-based event publishing system routing server events to typed subjects
// ABOUTME: Provides type-safe event streams for player updates, queue updates, library updates, and raw events

@preconcurrency import Combine
import Foundation

// Note: EventPublisher is @unchecked Sendable because PassthroughSubject doesn't conform to Sendable in older Combine
// versions. The class is immutable after init and all send() calls are dispatched to MainActor for thread safety.
public final class EventPublisher: @unchecked Sendable {
    public let playerUpdates = PassthroughSubject<PlayerUpdateEvent, Never>()
    public let queueUpdates = PassthroughSubject<QueueUpdateEvent, Never>()
    public let builtinPlayerEvents = PassthroughSubject<(String, BuiltinPlayerEvent), Never>()
    public let mediaItemUpdates = PassthroughSubject<MediaItemEvent, Never>()
    public let rawEvents = PassthroughSubject<Event, Never>()

    public init() {}

    public func publish(_ event: Event) async {
        // Dispatch all Combine send() calls to MainActor to avoid actor isolation crashes
        await MainActor.run {
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

            case "builtin_player":
                if let playerId = event.objectId,
                   let dataWrapper = event.data,
                   let dataDict = dataWrapper.value as? [String: Any] {
                    // Convert [String: Any] to [String: AnyCodable]
                    let anyCodableDict = dataDict.mapValues { AnyCodable($0) }
                    if let builtinEvent = try? BuiltinPlayerEvent(from: anyCodableDict) {
                        builtinPlayerEvents.send((playerId, builtinEvent))
                    }
                }

            case "media_item_added", "media_item_updated", "media_item_deleted", "media_item_played":
                if let dataWrapper = event.data,
                   let dataDict = dataWrapper.value as? [String: Any] {
                    // Convert [String: Any] to [String: AnyCodable]
                    let anyCodableDict = dataDict.mapValues { AnyCodable($0) }

                    // Extract media type from data or default to unknown
                    let mediaTypeString = anyCodableDict["media_type"]?.value as? String ?? "unknown"
                    let mediaType = MediaType(rawValue: mediaTypeString) ?? .unknown

                    // Determine action from event type
                    let action = MediaItemAction(rawValue: event.event) ?? .updated

                    // Create and publish media item event
                    let mediaEvent = MediaItemEvent(
                        action: action,
                        itemId: event.objectId,
                        mediaType: mediaType,
                        data: anyCodableDict
                    )
                    mediaItemUpdates.send(mediaEvent)
                }

            default:
                // Other events are only published as raw events
                break
            }
        }
    }
}
