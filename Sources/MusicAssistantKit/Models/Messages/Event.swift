// ABOUTME: Event message broadcast by Music Assistant server for state changes
// ABOUTME: Contains event type, optional object_id for filtering, and event data payload

import Foundation

struct Event: Codable {
    let event: String
    let objectId: String?
    let data: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case event
        case objectId = "object_id"
        case data
    }
}
