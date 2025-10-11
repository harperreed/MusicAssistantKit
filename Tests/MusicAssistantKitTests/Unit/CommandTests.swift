// ABOUTME: Unit tests for Command message encoding and JSON serialization
// ABOUTME: Validates snake_case conversion and proper structure of command messages

import Foundation
@testable import MusicAssistantKit
import Testing

@Suite("Command Encoding Tests")
struct CommandTests {
    @Test("Command encodes with snake_case keys")
    func commandEncodesWithSnakeCase() throws {
        let command = Command(messageId: 123, command: "players/all", args: nil)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(command)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["message_id"] as? Int == 123)
        #expect(json?["command"] as? String == "players/all")
    }

    @Test("Command encodes with args")
    func commandEncodesWithArgs() throws {
        let args: [String: AnyCodable] = [
            "player_id": AnyCodable("test-player"),
            "volume": AnyCodable(50),
        ]
        let command = Command(messageId: 456, command: "players/cmd/volume_set", args: args)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(command)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["message_id"] as? Int == 456)
        #expect(json?["command"] as? String == "players/cmd/volume_set")

        let jsonArgs = json?["args"] as? [String: Any]
        #expect(jsonArgs?["player_id"] as? String == "test-player")
        #expect(jsonArgs?["volume"] as? Int == 50)
    }

    @Test("Command decodes from JSON")
    func commandDecodesFromJSON() throws {
        let json = """
        {
            "message_id": 789,
            "command": "music/search",
            "args": {
                "search_query": "test",
                "limit": 25
            }
        }
        """

        let decoder = JSONDecoder()
        let data = try #require(json.data(using: .utf8))
        let command = try decoder.decode(Command.self, from: data)

        #expect(command.messageId == 789)
        #expect(command.command == "music/search")
        #expect(command.args?["search_query"]?.value as? String == "test")
        #expect(command.args?["limit"]?.value as? Int == 25)
    }

    @Test("Command decodes without args")
    func commandDecodesWithoutArgs() throws {
        let json = """
        {
            "message_id": 999,
            "command": "players/all"
        }
        """

        let decoder = JSONDecoder()
        let data = try #require(json.data(using: .utf8))
        let command = try decoder.decode(Command.self, from: data)

        #expect(command.messageId == 999)
        #expect(command.command == "players/all")
        #expect(command.args == nil)
    }
}
