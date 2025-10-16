@testable import MusicAssistantKit

// swiftlint:disable force_unwrapping
import XCTest

final class StreamURLTests: XCTestCase {
    func testStreamURLConstruction() throws {
        let baseURL = URL(string: "http://192.168.23.196:8095")!

        let streamURL = StreamURL(
            baseURL: baseURL,
            mediaPath: "flow/session123/queue456/item789.mp3"
        )

        XCTAssertEqual(
            streamURL.url.absoluteString,
            "http://192.168.23.196:8095/flow/session123/queue456/item789.mp3"
        )
    }

    func testQueueStreamURL() throws {
        let url = StreamURL.queueStream(
            baseURL: URL(string: "http://192.168.23.196:8095")!,
            sessionId: "session123",
            queueId: "queue456",
            queueItemId: "item789",
            format: .mp3,
            flowMode: true
        )

        XCTAssertEqual(
            url.url.absoluteString,
            "http://192.168.23.196:8095/flow/session123/queue456/item789.mp3"
        )
    }

    func testSingleItemStreamURL() throws {
        let url = StreamURL.queueStream(
            baseURL: URL(string: "http://192.168.23.196:8095")!,
            sessionId: "session123",
            queueId: "queue456",
            queueItemId: "item789",
            format: .flac,
            flowMode: false
        )

        XCTAssertEqual(
            url.url.absoluteString,
            "http://192.168.23.196:8095/single/session123/queue456/item789.flac"
        )
    }

    func testPreviewURL() throws {
        let url = StreamURL.preview(
            baseURL: URL(string: "http://192.168.23.196:8095")!,
            itemId: "track123",
            provider: "library"
        )

        // Item ID should be double-encoded
        XCTAssertTrue(url.url.absoluteString.contains("/preview?"))
        XCTAssertTrue(url.url.absoluteString.contains("item_id="))
        XCTAssertTrue(url.url.absoluteString.contains("provider=library"))
    }

    func testAnnouncementURL() throws {
        let url = StreamURL.announcement(
            baseURL: URL(string: "http://192.168.23.196:8095")!,
            playerId: "player1",
            format: .mp3,
            preAnnounce: true
        )

        XCTAssertTrue(url.url.absoluteString.contains("/announcement/player1.mp3"))
        XCTAssertTrue(url.url.absoluteString.contains("pre_announce=true"))
    }

    func testPluginSourceURL() throws {
        let url = StreamURL.pluginSource(
            baseURL: URL(string: "http://192.168.23.196:8095")!,
            pluginSource: "airplay",
            playerId: "player1",
            format: .flac
        )

        XCTAssertEqual(
            url.url.absoluteString,
            "http://192.168.23.196:8095/pluginsource/airplay/player1.flac"
        )
    }
}
