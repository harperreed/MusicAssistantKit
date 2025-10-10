// ABOUTME: Error message received when command fails on Music Assistant server
// ABOUTME: Contains error message, optional code, details, and debug information

import Foundation

public struct ErrorResponse: Codable {
    let messageId: Int
    let error: String
    let errorCode: Int?
    let details: [String: AnyCodable]?
    let exception: String?
    let stacktrace: String?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case error
        case errorCode = "error_code"
        case details
        case exception
        case stacktrace
    }
}
