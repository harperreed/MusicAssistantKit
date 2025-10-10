// ABOUTME: Unit tests for Result message decoding from command responses
// ABOUTME: Validates message_id correlation and result payload handling

import Foundation
import Testing
@testable import MusicAssistantKit

@Suite("Result Decoding Tests")
struct ResultTests {

    @Test("Result decodes with simple value")
    func resultDecodesWithSimpleValue() throws {
        let json = """
        {
            "message_id": 123,
            "result": "success"
        }
        """

        let decoder = JSONDecoder()
        let result = try decoder.decode(Result.self, from: json.data(using: .utf8)!)

        #expect(result.messageId == 123)
        #expect(result.result?.value as? String == "success")
    }

    @Test("Result decodes with missing result field")
    func resultDecodesWithMissingResult() throws {
        let json = """
        {
            "message_id": 456
        }
        """

        let decoder = JSONDecoder()
        let result = try decoder.decode(Result.self, from: json.data(using: .utf8)!)

        #expect(result.messageId == 456)
        #expect(result.result == nil)
    }

    @Test("Result decodes with object result")
    func resultDecodesWithObjectResult() throws {
        let json = """
        {
            "message_id": 789,
            "result": {
                "player_id": "test-player",
                "state": "playing",
                "volume": 50
            }
        }
        """

        let decoder = JSONDecoder()
        let result = try decoder.decode(Result.self, from: json.data(using: .utf8)!)

        #expect(result.messageId == 789)

        let data = result.result?.value as? [String: Any]
        #expect(data?["player_id"] as? String == "test-player")
        #expect(data?["state"] as? String == "playing")
        #expect(data?["volume"] as? Int == 50)
    }

    @Test("Result decodes with array result")
    func resultDecodesWithArrayResult() throws {
        let json = """
        {
            "message_id": 999,
            "result": [
                {"id": 1, "name": "Item 1"},
                {"id": 2, "name": "Item 2"}
            ]
        }
        """

        let decoder = JSONDecoder()
        let result = try decoder.decode(Result.self, from: json.data(using: .utf8)!)

        #expect(result.messageId == 999)

        let items = result.result?.value as? [[String: Any]]
        #expect(items?.count == 2)
        #expect(items?[0]["name"] as? String == "Item 1")
    }

    @Test("Result decodes with boolean result")
    func resultDecodesWithBooleanResult() throws {
        let json = """
        {
            "message_id": 111,
            "result": true
        }
        """

        let decoder = JSONDecoder()
        let result = try decoder.decode(Result.self, from: json.data(using: .utf8)!)

        #expect(result.messageId == 111)
        #expect(result.result?.value as? Bool == true)
    }

    @Test("Result decodes with number result")
    func resultDecodesWithNumberResult() throws {
        let json = """
        {
            "message_id": 222,
            "result": 42
        }
        """

        let decoder = JSONDecoder()
        let result = try decoder.decode(Result.self, from: json.data(using: .utf8)!)

        #expect(result.messageId == 222)
        #expect(result.result?.value as? Int == 42)
    }
}
