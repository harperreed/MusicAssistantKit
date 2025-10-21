// ABOUTME: State model for built-in player, sent to server via builtin_player/update_state
// ABOUTME: Tracks current playback state including power, playback status, position, volume, and mute state

import Foundation

public struct BuiltinPlayerState: Codable, Sendable {
    public let powered: Bool
    public let playing: Bool
    public let paused: Bool
    public let position: Double  // Position in seconds
    public let volume: Double    // Volume level 0-100
    public let muted: Bool

    public init(
        powered: Bool,
        playing: Bool,
        paused: Bool,
        position: Double,
        volume: Double,
        muted: Bool
    ) {
        self.powered = powered
        self.playing = playing
        self.paused = paused
        self.position = position
        self.volume = volume
        self.muted = muted
    }
}
