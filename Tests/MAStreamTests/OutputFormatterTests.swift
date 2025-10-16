// ABOUTME: Unit tests for OutputFormatter ANSI color and JSON output
// ABOUTME: Validates formatting of stream events and test results

import XCTest
@testable import MAStreamLib
import MusicAssistantKit

final class OutputFormatterTests: XCTestCase {
    func testFormatStreamEvent() {
        let formatter = OutputFormatter(jsonMode: false, colorEnabled: false)
        let event = BuiltinPlayerEvent(
            command: .playMedia,
            mediaUrl: "flow/session123/queue456/item789.mp3",
            queueId: "queue456",
            queueItemId: "item789"
        )

        let output = formatter.formatStreamEvent(event, streamURL: "http://localhost:8095/flow/session123/queue456/item789.mp3")

        XCTAssertTrue(output.contains("PLAY_MEDIA"))
        XCTAssertTrue(output.contains("queue456"))
        XCTAssertTrue(output.contains("item789"))
        XCTAssertTrue(output.contains("http://localhost:8095"))
        XCTAssertTrue(output.contains("mp3"))
    }

    func testFormatTestResult() {
        let formatter = OutputFormatter(jsonMode: false, colorEnabled: false)
        let result = TestResult(
            url: URL(string: "http://localhost:8095/test.mp3")!,
            statusCode: 200,
            responseTime: 0.123,
            error: nil
        )

        let output = formatter.formatTestResult(result)

        XCTAssertTrue(output.contains("200"))
        XCTAssertTrue(output.contains("Accessible"))
    }

    func testJSONMode() throws {
        let formatter = OutputFormatter(jsonMode: true, colorEnabled: false)
        let event = BuiltinPlayerEvent(
            command: .playMedia,
            mediaUrl: "flow/session/queue/item.mp3",
            queueId: "queue",
            queueItemId: "item"
        )

        let output = formatter.formatStreamEvent(event, streamURL: "http://localhost:8095/flow/session/queue/item.mp3")

        // Should be valid JSON
        let json = try JSONSerialization.jsonObject(with: output.data(using: .utf8)!) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["command"] as? String, "PLAY_MEDIA")
        XCTAssertEqual(json?["stream_url"] as? String, "http://localhost:8095/flow/session/queue/item.mp3")
    }
}
