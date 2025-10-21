// ABOUTME: Unit tests for streaming commands and Resonate protocol capability detection
// ABOUTME: Tests getStreamURL, getResonateStream, and supportsResonateProtocol methods

import XCTest
@testable import MusicAssistantKit

final class StreamingCommandsTests: XCTestCase {
    func testSupportsResonateProtocol_whenCapabilityPresent() async throws {
        let mock = MockWebSocketConnection()
        await mock.setCapabilities(["resonate", "search", "players"])

        let client = MusicAssistantClient(connection: mock)
        try await client.connect()

        let supportsResonate = await client.supportsResonateProtocol()
        XCTAssertTrue(supportsResonate)
    }

    func testSupportsResonateProtocol_whenCapabilityAbsent() async throws {
        let mock = MockWebSocketConnection()
        await mock.setCapabilities(["search", "players"])

        let client = MusicAssistantClient(connection: mock)
        try await client.connect()

        let supportsResonate = await client.supportsResonateProtocol()
        XCTAssertFalse(supportsResonate)
    }

    func testSupportsResonateProtocol_whenNotConnected() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        let supportsResonate = await client.supportsResonateProtocol()
        XCTAssertFalse(supportsResonate)
    }

    func testGetServerInfo_whenConnected() async throws {
        let mock = MockWebSocketConnection()
        await mock.setCapabilities(["resonate"])
        await mock.setBaseUrl("http://192.168.1.100:8095")

        let client = MusicAssistantClient(connection: mock)
        try await client.connect()

        let serverInfo = await client.getServerInfo()
        XCTAssertNotNil(serverInfo)
        XCTAssertEqual(serverInfo?.serverVersion, "2.0.0-test")
        XCTAssertEqual(serverInfo?.baseUrl, "http://192.168.1.100:8095")
        XCTAssertTrue(serverInfo?.capabilities?.contains("resonate") ?? false)
    }

    func testGetServerInfo_whenNotConnected() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        let serverInfo = await client.getServerInfo()
        XCTAssertNil(serverInfo)
    }

    func testGetStreamURL_sendsCorrectCommand() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)
        try await client.connect()

        // Simulate a successful response
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if let cmd = await mock.getLastCommand() {
                let streamInfo = StreamingInfo(
                    url: "ws://example.com/stream",
                    protocol: .resonate,
                    format: AudioFormat(codec: "flac", sampleRate: 48000),
                    mediaItemId: "track_123"
                )
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase
                let data = try encoder.encode(streamInfo)
                let json = try JSONSerialization.jsonObject(with: data)
                await mock.simulateResult(messageId: cmd.messageId, result: AnyCodable(json))
            }
        }

        let result = try await client.getStreamURL(mediaItemId: "track_123", preferredProtocol: .resonate)

        // Verify command was sent correctly
        let lastCmd = await mock.getLastCommand()
        XCTAssertNotNil(lastCmd)
        XCTAssertEqual(lastCmd?.command, "music/get_stream_url")

        // Verify result
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.protocol, .resonate)
        XCTAssertEqual(result?.mediaItemId, "track_123")
    }

    func testGetResonateStream_sendsCorrectCommand() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)
        try await client.connect()

        // Simulate a successful response
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if let cmd = await mock.getLastCommand() {
                let streamInfo = StreamingInfo(
                    url: "ws://192.168.1.100:8095/resonate/stream/queue_456",
                    protocol: .resonate,
                    format: AudioFormat(codec: "flac", sampleRate: 48000, bitDepth: 16),
                    queueId: "queue_456",
                    supportsSeek: true
                )
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase
                let data = try encoder.encode(streamInfo)
                let json = try JSONSerialization.jsonObject(with: data)
                await mock.simulateResult(messageId: cmd.messageId, result: AnyCodable(json))
            }
        }

        let result = try await client.getResonateStream(queueId: "queue_456")

        // Verify command was sent correctly
        let lastCmd = await mock.getLastCommand()
        XCTAssertNotNil(lastCmd)
        XCTAssertEqual(lastCmd?.command, "player_queues/get_resonate_stream")

        // Verify result
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.protocol, .resonate)
        XCTAssertEqual(result?.queueId, "queue_456")
        XCTAssertTrue(result?.supportsSeek ?? false)
    }

    func testGetStreamURL_withHTTPProtocol() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)
        try await client.connect()

        // Simulate a successful HTTP stream response
        Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            if let cmd = await mock.getLastCommand() {
                let streamInfo = StreamingInfo(
                    url: "http://192.168.1.100:8095/stream/track_789.mp3",
                    protocol: .http,
                    format: AudioFormat(codec: "mp3", bitrate: 320),
                    mediaItemId: "track_789"
                )
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase
                let data = try encoder.encode(streamInfo)
                let json = try JSONSerialization.jsonObject(with: data)
                await mock.simulateResult(messageId: cmd.messageId, result: AnyCodable(json))
            }
        }

        let result = try await client.getStreamURL(mediaItemId: "track_789", preferredProtocol: .http)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.protocol, .http)
        XCTAssertEqual(result?.format.codec, "mp3")
    }

    // MARK: - Error Handling Tests

    func testGetStreamURL_whenServerReturnsError() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)
        try await client.connect()

        // Simulate server error
        Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            if let cmd = await mock.getLastCommand() {
                await mock.simulateError(
                    messageId: cmd.messageId,
                    error: "Media item not found",
                    code: 404
                )
            }
        }

        do {
            _ = try await client.getStreamURL(mediaItemId: "invalid_track", preferredProtocol: .resonate)
            XCTFail("Should have thrown error")
        } catch let error as MusicAssistantError {
            if case let .serverError(code, message, _) = error {
                XCTAssertEqual(code, 404)
                XCTAssertEqual(message, "Media item not found")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testGetStreamURL_whenInvalidResponse() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)
        try await client.connect()

        // Simulate invalid response (string instead of dictionary)
        Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            if let cmd = await mock.getLastCommand() {
                await mock.simulateResult(
                    messageId: cmd.messageId,
                    result: AnyCodable("just_a_string")
                )
            }
        }

        do {
            _ = try await client.getStreamURL(mediaItemId: "track_123")
            XCTFail("Should have thrown invalidResponse error")
        } catch MusicAssistantError.invalidResponse {
            // Expected error
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testGetStreamURL_whenMalformedJSON() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)
        try await client.connect()

        // Simulate malformed JSON (missing required fields)
        Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            if let cmd = await mock.getLastCommand() {
                // Missing required 'url' field
                let malformed = ["protocol": "resonate", "format": ["codec": "flac"]]
                await mock.simulateResult(messageId: cmd.messageId, result: AnyCodable(malformed))
            }
        }

        do {
            _ = try await client.getStreamURL(mediaItemId: "track_123")
            XCTFail("Should have thrown decodingFailed error")
        } catch MusicAssistantError.decodingFailed {
            // Expected error
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testGetResonateStream_whenServerReturnsNull() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)
        try await client.connect()

        // Simulate null response (queue not found)
        Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            if let cmd = await mock.getLastCommand() {
                await mock.simulateResult(messageId: cmd.messageId, result: nil)
            }
        }

        let result = try await client.getResonateStream(queueId: "nonexistent_queue")
        XCTAssertNil(result)
    }

    func testGetResonateStream_whenInvalidDictionary() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)
        try await client.connect()

        // Simulate response with wrong types
        Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            if let cmd = await mock.getLastCommand() {
                let invalid = [
                    "url": 12345, // Wrong type - should be string
                    "protocol": "resonate",
                ] as [String: Any]
                await mock.simulateResult(messageId: cmd.messageId, result: AnyCodable(invalid))
            }
        }

        do {
            _ = try await client.getResonateStream(queueId: "queue_123")
            XCTFail("Should have thrown decodingFailed error")
        } catch MusicAssistantError.decodingFailed {
            // Expected error
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
