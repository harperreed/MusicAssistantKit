// ABOUTME: Unit tests for Result message decoding from command responses
// ABOUTME: Validates message_id correlation and result payload handling

import Foundation
@testable import MusicAssistantKit
import Testing

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

    @Test("Result decodes with double result")
    func resultDecodesWithDoubleResult() throws {
        let json = """
        {
            "message_id": 333,
            "result": 3.14
        }
        """

        let decoder = JSONDecoder()
        let result = try decoder.decode(Result.self, from: json.data(using: .utf8)!)

        #expect(result.messageId == 333)
        #expect(result.result?.value as? Double == 3.14)
    }

    @Test("Result decodes with null result")
    func resultDecodesWithNullResult() throws {
        let json = """
        {
            "message_id": 444,
            "result": null
        }
        """

        let decoder = JSONDecoder()
        let result = try decoder.decode(Result.self, from: json.data(using: .utf8)!)

        #expect(result.messageId == 444)
        // When result is null, it's decoded as nil, not AnyCodable(NSNull)
        // This is correct behavior - optional result field handles null
        #expect(result.result == nil)
    }

    // MARK: - AnyCodable Encoding Tests

    @Test("AnyCodable encodes integer")
    func anyCodableEncodesInteger() throws {
        let anyCodable = AnyCodable(42)
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let decoded = try JSONDecoder().decode(Int.self, from: data)

        #expect(decoded == 42)
    }

    @Test("AnyCodable encodes double")
    func anyCodableEncodesDouble() throws {
        let anyCodable = AnyCodable(3.14)
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let decoded = try JSONDecoder().decode(Double.self, from: data)

        #expect(decoded == 3.14)
    }

    @Test("AnyCodable encodes string")
    func anyCodableEncodesString() throws {
        let anyCodable = AnyCodable("hello")
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let decoded = try JSONDecoder().decode(String.self, from: data)

        #expect(decoded == "hello")
    }

    @Test("AnyCodable encodes boolean")
    func anyCodableEncodesBoolean() throws {
        let anyCodable = AnyCodable(true)
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let decoded = try JSONDecoder().decode(Bool.self, from: data)

        #expect(decoded == true)
    }

    @Test("AnyCodable encodes array")
    func anyCodableEncodesArray() throws {
        let anyCodable = AnyCodable([1, 2, 3] as [Any])
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let decoded = try JSONDecoder().decode([Int].self, from: data)

        #expect(decoded == [1, 2, 3])
    }

    @Test("AnyCodable encodes dictionary")
    func anyCodableEncodesDictionary() throws {
        let anyCodable = AnyCodable(["key": "value"] as [String: Any])
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let decoded = try JSONDecoder().decode([String: String].self, from: data)

        #expect(decoded == ["key": "value"])
    }

    @Test("AnyCodable encodes NSNull")
    func anyCodableEncodesNSNull() throws {
        let anyCodable = AnyCodable(NSNull())
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let string = String(data: data, encoding: .utf8)

        #expect(string == "null")
    }
}
