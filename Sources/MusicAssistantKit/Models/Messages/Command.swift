// ABOUTME: Command message sent from client to Music Assistant server
// ABOUTME: Contains message_id for response correlation, command string, and optional args

import Foundation

struct Command: Codable {
    let messageId: Int
    let command: String
    let args: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case command
        case args
    }

    init(messageId: Int, command: String, args: [String: Any]? = nil) {
        self.messageId = messageId
        self.command = command
        self.args = args
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageId, forKey: .messageId)
        try container.encode(command, forKey: .command)
        if let args = args {
            let data = try JSONSerialization.data(withJSONObject: args)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            try container.encode(jsonObject as? [String: String], forKey: .args)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageId = try container.decode(Int.self, forKey: .messageId)
        command = try container.decode(String.self, forKey: .command)
        args = try? container.decode([String: String].self, forKey: .args) as [String: Any]
    }
}
