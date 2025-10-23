// ABOUTME: Media item (library content) change event from Music Assistant server
// ABOUTME: Published when artists, albums, tracks, playlists are added/updated/deleted

import Foundation

/// Type of media item update action
public enum MediaItemAction: String, Sendable {
    case added = "media_item_added"
    case updated = "media_item_updated"
    case deleted = "media_item_deleted"
    case played = "media_item_played"
}

/// Media type categorization
public enum MediaType: String, Sendable {
    case artist
    case album
    case track
    case playlist
    case radio
    case unknown
}

/// Event emitted when library content changes (items added, updated, or deleted)
public struct MediaItemEvent: @unchecked Sendable {
    /// The action that triggered this event
    public let action: MediaItemAction

    /// Unique identifier of the media item (e.g., artist ID, album ID, track ID)
    public let itemId: String?

    /// Type of media item affected
    public let mediaType: MediaType

    /// Full event data payload from server
    public let data: [String: AnyCodable]

    public init(action: MediaItemAction, itemId: String?, mediaType: MediaType, data: [String: AnyCodable]) {
        self.action = action
        self.itemId = itemId
        self.mediaType = mediaType
        self.data = data
    }
}
