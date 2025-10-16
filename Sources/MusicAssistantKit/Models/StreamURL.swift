// ABOUTME: Represents a Music Assistant streaming audio URL with construction helpers
// ABOUTME: Handles different stream endpoint types and format options

import Foundation

public struct StreamURL: Sendable {
    public let url: URL

    /// Initialize with base URL and media path
    public init(baseURL: URL, mediaPath: String) {
        url = baseURL.appendingPathComponent(mediaPath)
    }

    /// Construct queue stream URL (flow or single mode)
    public static func queueStream(
        baseURL: URL,
        sessionId: String,
        queueId: String,
        queueItemId: String,
        format: StreamFormat,
        flowMode: Bool = true
    ) -> StreamURL {
        let mode = flowMode ? "flow" : "single"
        let path = "\(mode)/\(sessionId)/\(queueId)/\(queueItemId).\(format.rawValue)"
        return StreamURL(baseURL: baseURL, mediaPath: path)
    }

    /// Construct preview/clip URL
    public static func preview(
        baseURL: URL,
        itemId: String,
        provider: String
    ) -> StreamURL {
        // Item ID must be double URL-encoded
        let encoded = itemId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? itemId
        let doubleEncoded = encoded.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? encoded

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            fatalError("Invalid base URL provided: \(baseURL)")
        }
        components.path += "/preview"
        components.queryItems = [
            URLQueryItem(name: "item_id", value: doubleEncoded),
            URLQueryItem(name: "provider", value: provider),
        ]

        guard let url = components.url else {
            fatalError("Failed to construct preview URL from components")
        }
        return StreamURL(url: url)
    }

    /// Initialize with a complete URL (for URLs with query parameters)
    private init(url: URL) {
        self.url = url
    }

    /// Construct announcement URL
    public static func announcement(
        baseURL: URL,
        playerId: String,
        format: StreamFormat,
        preAnnounce: Bool = false
    ) -> StreamURL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            fatalError("Invalid base URL provided: \(baseURL)")
        }
        components.path += "/announcement/\(playerId).\(format.rawValue)"
        if preAnnounce {
            components.queryItems = [URLQueryItem(name: "pre_announce", value: "true")]
        }

        guard let url = components.url else {
            fatalError("Failed to construct announcement URL from components")
        }
        return StreamURL(url: url)
    }

    /// Construct plugin source URL
    public static func pluginSource(
        baseURL: URL,
        pluginSource: String,
        playerId: String,
        format: StreamFormat
    ) -> StreamURL {
        let path = "pluginsource/\(pluginSource)/\(playerId).\(format.rawValue)"
        return StreamURL(baseURL: baseURL, mediaPath: path)
    }
}

public enum StreamFormat: String, Codable, Sendable {
    case mp3
    case flac
    case pcm
}
