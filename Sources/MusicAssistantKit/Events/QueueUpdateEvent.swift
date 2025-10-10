// ABOUTME: Queue state change event containing queue ID and updated state data
// ABOUTME: Published when queue items, playback mode, or queue settings change

import Foundation

public struct QueueUpdateEvent {
    public let queueId: String
    public let data: [String: AnyCodable]

    public init(queueId: String, data: [String: AnyCodable]) {
        self.queueId = queueId
        self.data = data
    }
}
