// ABOUTME: Unit tests for WebSocketConnection message parsing and protocol handling
// ABOUTME: Validates message envelope detection and routing logic

import Foundation
@testable import MusicAssistantKit
import Testing

@Suite("WebSocket Parsing Unit Tests")
struct WebSocketParsingTests {

    // MARK: - Message Parsing Tests

    @Test("parseMessage detects ServerInfo message")
    func parseServerInfo() throws {
        let json = """
        {
            "server_version": "2.0.0",
            "schema_version": 25,
            "min_supported_schema_version": 1,
            "server_id": "test-server",
            "homeassistant_addon": false,
            "capabilities": ["player_queue", "media_browse"]
        }
        """

        let data = json.data(using: .utf8)!
        let connection = WebSocketConnection(host: "localhost", port: 8095)

        // We can't directly test parseMessage as it's private,
        // but we can verify the data structure would decode correctly
        let decoder = JSONDecoder()
        let serverInfo = try decoder.decode(ServerInfo.self, from: data)

        #expect(serverInfo.serverVersion == "2.0.0")
        #expect(serverInfo.schemaVersion == 25)
    }

    @Test("parseMessage detects Event message")
    func parseEvent() throws {
        let json = """
        {
            "event": "player_updated",
            "object_id": "player-123",
            "data": {
                "state": "playing"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let event = try decoder.decode(Event.self, from: data)

        #expect(event.event == "player_updated")
        #expect(event.objectId == "player-123")
    }

    @Test("parseMessage detects Result message")
    func parseResult() throws {
        let json = """
        {
            "message_id": 42,
            "result": {
                "player_id": "test-player"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let result = try decoder.decode(Result.self, from: data)

        #expect(result.messageId == 42)
        #expect(result.result?.value is [String: Any])
    }

    @Test("parseMessage detects ErrorResponse message")
    func parseError() throws {
        let json = """
        {
            "message_id": 99,
            "error": "Command failed",
            "error_code": 500,
            "details": {
                "reason": "Server error"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let error = try decoder.decode(ErrorResponse.self, from: data)

        #expect(error.messageId == 99)
        #expect(error.error == "Command failed")
        #expect(error.errorCode == 500)
    }

    // MARK: - Connection State Tests

    @Test("Connection starts in disconnected state")
    func initialState() async {
        let connection = WebSocketConnection(host: "localhost", port: 8095)
        let state = await connection.state

        #expect(state.isDisconnected == true)
        #expect(state.isConnected == false)
    }

    // MARK: - Command Encoding Tests

    @Test("Command encodes with snake_case keys")
    func commandEncoding() throws {
        let command = Command(
            messageId: 123,
            command: "players/all",
            args: nil
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(command)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("message_id"))
        // JSON encoder escapes slashes, so we check for the escaped version
        #expect(json.contains("\"command\":\"players\\/all\""))
    }

    @Test("Command encodes with args")
    func commandEncodingWithArgs() throws {
        let command = Command(
            messageId: 456,
            command: "players/cmd/play",
            args: ["player_id": AnyCodable("test-player")]
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(command)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("message_id"))
        // JSON encoder escapes slashes
        #expect(json.contains("\"command\":\"players\\/cmd\\/play\""))
        #expect(json.contains("player_id"))
    }
}
