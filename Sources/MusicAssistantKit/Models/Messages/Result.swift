// ABOUTME: Result message received from Music Assistant server in response to commands
// ABOUTME: Contains message_id matching original command and result payload

import Foundation

public struct Result: Codable {
    let messageId: Int
    let result: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case result
    }
}

// Helper for decoding arbitrary JSON
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        case let bool as Bool: try container.encode(bool)
        case let array as [Any]: try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyCodable($0) })
        case is NSNull: try container.encodeNil()
        default: throw EncodingError.invalidValue(value, .init(codingPath: [], debugDescription: "Unsupported type"))
        }
    }
}
