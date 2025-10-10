// ABOUTME: Server information banner sent immediately after WebSocket connection
// ABOUTME: Contains version info and capabilities for feature detection

import Foundation

public struct ServerInfo: Codable, Sendable {
    public let serverVersion: String
    public let schemaVersion: Int?
    public let minSupportedSchemaVersion: Int?
    public let serverId: String?
    public let homeassistantAddon: Bool?
    public let capabilities: [String]?
    public let baseUrl: String?
    public let onboardDone: Bool?

    enum CodingKeys: String, CodingKey {
        case serverVersion = "server_version"
        case schemaVersion = "schema_version"
        case minSupportedSchemaVersion = "min_supported_schema_version"
        case serverId = "server_id"
        case homeassistantAddon = "homeassistant_addon"
        case capabilities
        case baseUrl = "base_url"
        case onboardDone = "onboard_done"
    }
}
