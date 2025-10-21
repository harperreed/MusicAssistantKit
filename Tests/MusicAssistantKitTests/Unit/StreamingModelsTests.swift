// ABOUTME: Unit tests for streaming models (StreamProtocol, AudioFormat, StreamingInfo)
// ABOUTME: Validates encoding/decoding and property behavior for Resonate protocol support

import XCTest
@testable import MusicAssistantKit

final class StreamingModelsTests: XCTestCase {
    func testStreamProtocolEncoding() throws {
        let resonate = StreamProtocol.resonate
        let encoder = JSONEncoder()
        let data = try encoder.encode(resonate)
        let string = String(data: data, encoding: .utf8)
        XCTAssertEqual(string, "\"resonate\"")
    }

    func testStreamProtocolDecoding() throws {
        let json = "\"resonate\"".data(using: .utf8)!
        let decoder = JSONDecoder()
        let proto = try decoder.decode(StreamProtocol.self, from: json)
        XCTAssertEqual(proto, .resonate)
    }

    func testAudioFormatLosslessDetection() {
        let flac = AudioFormat(codec: "flac", sampleRate: 44100, bitDepth: 16)
        XCTAssertTrue(flac.isLossless)

        let mp3 = AudioFormat(codec: "mp3", bitrate: 320)
        XCTAssertFalse(mp3.isLossless)

        let alac = AudioFormat(codec: "alac", sampleRate: 48000, bitDepth: 24)
        XCTAssertTrue(alac.isLossless)
    }

    func testAudioFormatEncoding() throws {
        let format = AudioFormat(
            codec: "flac",
            sampleRate: 96000,
            bitDepth: 24,
            bitrate: nil,
            channels: 2
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(format)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["codec"] as? String, "flac")
        XCTAssertEqual(json["sample_rate"] as? Int, 96000)
        XCTAssertEqual(json["bit_depth"] as? Int, 24)
        XCTAssertEqual(json["channels"] as? Int, 2)
    }

    func testAudioFormatDecoding() throws {
        let json = """
        {
            "codec": "flac",
            "sample_rate": 96000,
            "bit_depth": 24,
            "channels": 2
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let format = try decoder.decode(AudioFormat.self, from: json)

        XCTAssertEqual(format.codec, "flac")
        XCTAssertEqual(format.sampleRate, 96000)
        XCTAssertEqual(format.bitDepth, 24)
        XCTAssertEqual(format.channels, 2)
        XCTAssertTrue(format.isLossless)
    }

    func testStreamingInfoEncoding() throws {
        let format = AudioFormat(codec: "flac", sampleRate: 48000, bitDepth: 16)
        let streamInfo = StreamingInfo(
            url: "ws://192.168.1.100:8095/resonate/stream/queue_123",
            protocol: .resonate,
            format: format,
            mediaItemId: nil,
            queueId: "queue_123",
            duration: 245.5,
            supportsSeek: true,
            isLive: false
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(streamInfo)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["url"] as? String, "ws://192.168.1.100:8095/resonate/stream/queue_123")
        XCTAssertEqual(json["protocol"] as? String, "resonate")
        XCTAssertEqual(json["queue_id"] as? String, "queue_123")
        XCTAssertEqual(json["duration"] as? Double, 245.5)
        XCTAssertEqual(json["supports_seek"] as? Bool, true)
        XCTAssertEqual(json["is_live"] as? Bool, false)
    }

    func testStreamingInfoDecoding() throws {
        let json = """
        {
            "url": "ws://192.168.1.100:8095/resonate/stream/queue_123",
            "protocol": "resonate",
            "format": {
                "codec": "flac",
                "sample_rate": 48000,
                "bit_depth": 16,
                "channels": 2
            },
            "queue_id": "queue_123",
            "duration": 245.5,
            "supports_seek": true,
            "is_live": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let streamInfo = try decoder.decode(StreamingInfo.self, from: json)

        XCTAssertEqual(streamInfo.url, "ws://192.168.1.100:8095/resonate/stream/queue_123")
        XCTAssertEqual(streamInfo.`protocol`, .resonate)
        XCTAssertEqual(streamInfo.format.codec, "flac")
        XCTAssertEqual(streamInfo.format.sampleRate, 48000)
        XCTAssertEqual(streamInfo.queueId, "queue_123")
        XCTAssertEqual(streamInfo.duration, 245.5)
        XCTAssertTrue(streamInfo.supportsSeek)
        XCTAssertFalse(streamInfo.isLive)
    }

    func testStreamingInfoMediaItem() throws {
        let format = AudioFormat(codec: "mp3", bitrate: 320)
        let streamInfo = StreamingInfo(
            url: "https://example.com/stream/track_456.mp3",
            protocol: .https,
            format: format,
            mediaItemId: "track_456",
            queueId: nil,
            duration: 180.0
        )

        XCTAssertEqual(streamInfo.mediaItemId, "track_456")
        XCTAssertNil(streamInfo.queueId)
        XCTAssertEqual(streamInfo.`protocol`, .https)
    }
}
