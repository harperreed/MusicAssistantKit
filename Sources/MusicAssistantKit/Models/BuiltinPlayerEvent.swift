// ABOUTME: Represents events sent to built-in web player with streaming URLs
// ABOUTME: Used to extract media_url for client-side audio playback

import Foundation

public struct BuiltinPlayerEvent: Codable, Sendable {
    public let command: Command
    public let mediaUrl: String?
    public let queueId: String?
    public let queueItemId: String?

    enum CodingKeys: String, CodingKey {
        case command
        case mediaUrl = "media_url"
        case queueId = "queue_id"
        case queueItemId = "queue_item_id"
    }

    public enum Command: String, Codable, Sendable {
        case playMedia = "PLAY_MEDIA"
        case stop = "STOP"
        case pause = "PAUSE"
        case unpause = "UNPAUSE"
        case next = "NEXT"
        case previous = "PREVIOUS"
        case unknown

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = Command(rawValue: rawValue) ?? .unknown
        }
    }
}
