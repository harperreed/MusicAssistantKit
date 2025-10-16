// ABOUTME: Represents a Music Assistant streaming audio URL with construction helpers
// ABOUTME: Handles different stream endpoint types and format options

import Foundation

public enum StreamURLError: Error, Sendable {
    case invalidBaseURL(URL)
    case failedToConstructURL(String)
}

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
    ) throws -> StreamURL {
        // Item ID must be double URL-encoded for Music Assistant
        // We manually construct the query string to avoid URLComponents adding a third encoding

        // Use alphanumerics + unreserved chars for strict encoding
        // This ensures colons, slashes, etc. get encoded
        var allowedChars = CharacterSet.alphanumerics
        allowedChars.insert(charactersIn: "-._~") // RFC 3986 unreserved characters

        guard let encoded = itemId.addingPercentEncoding(withAllowedCharacters: allowedChars),
              let doubleEncoded = encoded.addingPercentEncoding(withAllowedCharacters: allowedChars) else {
            throw StreamURLError.failedToConstructURL("preview URL - encoding failed for item_id")
        }

        // Provider needs single encoding
        guard let encodedProvider = provider.addingPercentEncoding(withAllowedCharacters: allowedChars) else {
            throw StreamURLError.failedToConstructURL("preview URL - encoding failed for provider")
        }

        var urlString = baseURL.absoluteString
        if !urlString.hasSuffix("/") {
            urlString += "/"
        }
        urlString += "preview?item_id=\(doubleEncoded)&provider=\(encodedProvider)"

        guard let url = URL(string: urlString) else {
            throw StreamURLError.failedToConstructURL("preview URL from \(baseURL)")
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
    ) throws -> StreamURL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw StreamURLError.invalidBaseURL(baseURL)
        }
        components.path += "/announcement/\(playerId).\(format.rawValue)"
        if preAnnounce {
            components.queryItems = [URLQueryItem(name: "pre_announce", value: "true")]
        }

        guard let url = components.url else {
            throw StreamURLError.failedToConstructURL("announcement URL from \(baseURL)")
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
