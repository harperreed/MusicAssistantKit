// ABOUTME: Command message sent from client to Music Assistant server
// ABOUTME: Contains message_id for response correlation, command string, and optional args

import Foundation

public struct Command: Codable, @unchecked Sendable {
    let messageId: Int
    let command: String
    let args: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case command
        case args
    }

    public init(messageId: Int, command: String, args: [String: AnyCodable]? = nil) {
        self.messageId = messageId
        self.command = command
        self.args = args
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageId, forKey: .messageId)
        try container.encode(command, forKey: .command)
        if let args {
            try container.encode(args, forKey: .args)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageId = try container.decode(Int.self, forKey: .messageId)
        command = try container.decode(String.self, forKey: .command)
        args = try container.decodeIfPresent([String: AnyCodable].self, forKey: .args)
    }
}
