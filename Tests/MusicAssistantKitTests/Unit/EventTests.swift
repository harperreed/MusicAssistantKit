// ABOUTME: Unit tests for Event message decoding from server broadcasts
// ABOUTME: Validates event structure, object_id handling, and data payload parsing

import Foundation
@testable import MusicAssistantKit
import Testing

@Suite("Event Decoding Tests")
struct EventTests {
    @Test("Event decodes with all fields")
    func eventDecodesWithAllFields() throws {
        let json = """
        {
            "event": "player_updated",
            "object_id": "player-123",
            "data": {
                "state": "playing",
                "volume": 75
            }
        }
        """

        let decoder = JSONDecoder()
        let jsonData = try #require(json.data(using: .utf8))
        let event = try decoder.decode(Event.self, from: jsonData)

        #expect(event.event == "player_updated")
        #expect(event.objectId == "player-123")

        let data = event.data?.value as? [String: Any]
        #expect(data?["state"] as? String == "playing")
        #expect(data?["volume"] as? Int == 75)
    }

    @Test("Event decodes without object_id")
    func eventDecodesWithoutObjectId() throws {
        let json = """
        {
            "event": "server_shutdown"
        }
        """

        let decoder = JSONDecoder()
        let jsonData = try #require(json.data(using: .utf8))
        let event = try decoder.decode(Event.self, from: jsonData)

        #expect(event.event == "server_shutdown")
        #expect(event.objectId == nil)
        #expect(event.data == nil)
    }

    @Test("Event decodes with null data")
    func eventDecodesWithNullData() throws {
        let json = """
        {
            "event": "queue_items_updated",
            "object_id": "queue-456"
        }
        """

        let decoder = JSONDecoder()
        let jsonData = try #require(json.data(using: .utf8))
        let event = try decoder.decode(Event.self, from: jsonData)

        #expect(event.event == "queue_items_updated")
        #expect(event.objectId == "queue-456")
        #expect(event.data == nil)
    }

    @Test("Event decodes with complex nested data")
    func eventDecodesWithNestedData() throws {
        let json = """
        {
            "event": "queue_updated",
            "object_id": "queue-789",
            "data": {
                "items": [
                    {"id": 1, "name": "Song 1"},
                    {"id": 2, "name": "Song 2"}
                ],
                "shuffle": true
            }
        }
        """

        let decoder = JSONDecoder()
        let jsonData = try #require(json.data(using: .utf8))
        let event = try decoder.decode(Event.self, from: jsonData)

        #expect(event.event == "queue_updated")
        #expect(event.objectId == "queue-789")

        let data = event.data?.value as? [String: Any]
        let items = data?["items"] as? [[String: Any]]
        #expect(items?.count == 2)
        #expect(data?["shuffle"] as? Bool == true)
    }
}
