// ABOUTME: Streaming information for media playback
// ABOUTME: Contains URL, protocol, format, and metadata for streaming audio

import Foundation

/// Complete streaming information for a media item
public struct StreamingInfo: Codable, Sendable {
    /// The streaming URL
    public let url: String

    /// The streaming protocol
    public let protocol: StreamProtocol

    /// Audio format information
    public let format: AudioFormat

    /// Media item ID this stream is for
    public let mediaItemId: String?

    /// Queue ID if this is for queue-based streaming (Resonate)
    public let queueId: String?

    /// Duration in seconds
    public let duration: Double?

    /// Additional metadata
    public let metadata: [String: AnyCodable]?

    /// Whether this stream supports seeking
    public let supportsSeek: Bool

    /// Whether this is a live stream
    public let isLive: Bool

    public init(
        url: String,
        protocol: StreamProtocol,
        format: AudioFormat,
        mediaItemId: String? = nil,
        queueId: String? = nil,
        duration: Double? = nil,
        metadata: [String: AnyCodable]? = nil,
        supportsSeek: Bool = true,
        isLive: Bool = false
    ) {
        self.url = url
        self.protocol = `protocol`
        self.format = format
        self.mediaItemId = mediaItemId
        self.queueId = queueId
        self.duration = duration
        self.metadata = metadata
        self.supportsSeek = supportsSeek
        self.isLive = isLive
    }

    enum CodingKeys: String, CodingKey {
        case url
        case `protocol`
        case format
        case mediaItemId = "media_item_id"
        case queueId = "queue_id"
        case duration
        case metadata
        case supportsSeek = "supports_seek"
        case isLive = "is_live"
    }
}
