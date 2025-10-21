// ABOUTME: Event model for built-in player events received from Music Assistant server
// ABOUTME: Handles player control commands like PLAY, PAUSE, STOP, PLAY_MEDIA, volume/power control

import Foundation

public enum BuiltinPlayerEventType: String, Codable, Sendable {
    case play = "PLAY"
    case pause = "PAUSE"
    case stop = "STOP"
    case playMedia = "PLAY_MEDIA"
    case setVolume = "SET_VOLUME"
    case mute = "MUTE"
    case unmute = "UNMUTE"
    case powerOn = "POWER_ON"
    case powerOff = "POWER_OFF"
    case timeout = "TIMEOUT"
}

public struct BuiltinPlayerEvent: Sendable {
    public let type: BuiltinPlayerEventType
    public let mediaUrl: String?
    public let volume: Double?

    public init(type: BuiltinPlayerEventType, mediaUrl: String? = nil, volume: Double? = nil) {
        self.type = type
        self.mediaUrl = mediaUrl
        self.volume = volume
    }

    public init(from data: [String: AnyCodable]) throws {
        guard let typeString = data["type"]?.value as? String,
              let type = BuiltinPlayerEventType(rawValue: typeString)
        else {
            throw MusicAssistantError.invalidResponse
        }

        self.type = type
        self.mediaUrl = data["media_url"]?.value as? String
        self.volume = data["volume"]?.value as? Double
    }
}
