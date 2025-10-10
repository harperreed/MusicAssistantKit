// ABOUTME: Player state change event containing player ID and updated state data
// ABOUTME: Published when player status, volume, or playback state changes

import Foundation

public struct PlayerUpdateEvent {
    public let playerId: String
    public let data: [String: AnyCodable]

    public init(playerId: String, data: [String: AnyCodable]) {
        self.playerId = playerId
        self.data = data
    }
}
