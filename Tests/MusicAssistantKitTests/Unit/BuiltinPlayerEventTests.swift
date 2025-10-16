import XCTest
@testable import MusicAssistantKit

final class BuiltinPlayerEventTests: XCTestCase {
    func testDecodePlayMediaEvent() throws {
        let json = """
        {
            "command": "PLAY_MEDIA",
            "media_url": "flow/session123/queue456/item789.mp3",
            "queue_id": "queue456",
            "queue_item_id": "item789"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(BuiltinPlayerEvent.self, from: json)

        XCTAssertEqual(event.command, .playMedia)
        XCTAssertEqual(event.mediaUrl, "flow/session123/queue456/item789.mp3")
        XCTAssertEqual(event.queueId, "queue456")
        XCTAssertEqual(event.queueItemId, "item789")
    }

    func testDecodeStopEvent() throws {
        let json = """
        {
            "command": "STOP"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(BuiltinPlayerEvent.self, from: json)

        XCTAssertEqual(event.command, .stop)
        XCTAssertNil(event.mediaUrl)
    }

    func testDecodeUnknownCommand() throws {
        let json = """
        {
            "command": "SOME_NEW_COMMAND",
            "media_url": "test.mp3"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(BuiltinPlayerEvent.self, from: json)

        XCTAssertEqual(event.command, .unknown)
        XCTAssertEqual(event.mediaUrl, "test.mp3")
    }
}
