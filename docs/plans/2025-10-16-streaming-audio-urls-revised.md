# Streaming Audio URLs Implementation Plan (REVISED)

> **For Claude:** Use `${SUPERPOWERS_SKILLS_ROOT}/skills/collaboration/executing-plans/SKILL.md` to implement this plan task-by-task.

**Goal:** Add ability to access streaming audio URLs from Music Assistant via event-based architecture and direct URL construction.

**Architecture:** Music Assistant exposes stream URLs through `BUILTIN_PLAYER` WebSocket events and HTTP endpoints. Clients receive `media_url` in events and combine with base URL to stream audio. We'll implement event parsing, URL construction helpers, and format selection.

**Tech Stack:** Swift 6.0, WebSocket protocol, Combine publishers, async/await, AVFoundation (for playback testing)

---

## Implementation Phase

### Task 1: Stream URL Models

**Files:**
- Create: `Sources/MusicAssistantKit/Models/StreamURL.swift`
- Test: `Tests/MusicAssistantKitTests/Unit/StreamURLTests.swift`

**Step 1: Write failing test for StreamURL model**

```swift
// Tests/MusicAssistantKitTests/Unit/StreamURLTests.swift
import XCTest
@testable import MusicAssistantKit

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
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter StreamURLTests
```

Expected: FAIL with "Type 'StreamURL' not found"

**Step 3: Implement StreamURL model**

```swift
// Sources/MusicAssistantKit/Models/StreamURL.swift
// ABOUTME: Represents a Music Assistant streaming audio URL with construction helpers
// ABOUTME: Handles different stream endpoint types and format options

import Foundation

public struct StreamURL: Sendable {
    public let url: URL

    /// Initialize with base URL and media path
    public init(baseURL: URL, mediaPath: String) {
        self.url = baseURL.appendingPathComponent(mediaPath)
    }

    /// Construct queue stream URL (flow or single mode)
    public static func queueStream(
        baseURL: URL,
        sessionId: String,
        queueId: String,
        queueItemId: String,
        format: StreamFormat,
        flowMode: Bool = true
    ) -> StreamURL {
        let mode = flowMode ? "flow" : "single"
        let path = "\(mode)/\(sessionId)/\(queueId)/\(queueItemId).\(format.rawValue)"
        return StreamURL(baseURL: baseURL, mediaPath: path)
    }

    /// Construct preview/clip URL
    public static func preview(
        baseURL: URL,
        itemId: String,
        provider: String
    ) -> StreamURL {
        // Item ID must be double URL-encoded
        let encoded = itemId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? itemId
        let doubleEncoded = encoded.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? encoded

        var components = URLComponents(url: baseURL.appendingPathComponent("preview"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "item_id", value: doubleEncoded),
            URLQueryItem(name: "provider", value: provider)
        ]

        return StreamURL(baseURL: baseURL, mediaPath: components.url!.path + "?" + components.query!)
    }

    /// Construct announcement URL
    public static func announcement(
        baseURL: URL,
        playerId: String,
        format: StreamFormat,
        preAnnounce: Bool = false
    ) -> StreamURL {
        var components = URLComponents(url: baseURL.appendingPathComponent("announcement/\(playerId).\(format.rawValue)"), resolvingAgainstBaseURL: false)!
        if preAnnounce {
            components.queryItems = [URLQueryItem(name: "pre_announce", value: "true")]
        }

        let path = components.url!.path + (components.query.map { "?\($0)" } ?? "")
        return StreamURL(baseURL: baseURL, mediaPath: path)
    }

    /// Construct plugin source URL
    public static func pluginSource(
        baseURL: URL,
        pluginSource: String,
        playerId: String,
        format: StreamFormat
    ) -> StreamURL {
        let path = "pluginsource/\(pluginSource)/\(playerId).\(format.rawValue)"
        return StreamURL(baseURL: baseURL, mediaPath: path)
    }
}

public enum StreamFormat: String, Codable, Sendable {
    case mp3
    case flac
    case pcm
}
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter StreamURLTests
```

Expected: PASS

**Step 5: Add test for announcement and plugin URLs**

```swift
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
```

**Step 6: Run tests to verify**

```bash
swift test --filter StreamURLTests
```

Expected: PASS (all tests)

**Step 7: Commit StreamURL model**

```bash
git add Sources/MusicAssistantKit/Models/StreamURL.swift \
        Tests/MusicAssistantKitTests/Unit/StreamURLTests.swift
git commit -m "feat: add StreamURL model with URL construction helpers

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: Built-in Player Event Model

**Files:**
- Create: `Sources/MusicAssistantKit/Models/BuiltinPlayerEvent.swift`
- Test: `Tests/MusicAssistantKitTests/Unit/BuiltinPlayerEventTests.swift`

**Step 1: Write failing test for BuiltinPlayerEvent**

```swift
// Tests/MusicAssistantKitTests/Unit/BuiltinPlayerEventTests.swift
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
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter BuiltinPlayerEventTests
```

Expected: FAIL with "Type 'BuiltinPlayerEvent' not found"

**Step 3: Implement BuiltinPlayerEvent model**

```swift
// Sources/MusicAssistantKit/Models/BuiltinPlayerEvent.swift
// ABOUTME: Represents events sent to built-in web player with streaming URLs
// ABOUTME: Used to extract media_url for client-side audio playback

import Foundation

public struct BuiltinPlayerEvent: Codable, Sendable {
    public let command: Command
    public let mediaUrl: String?
    public let queueId: String?
    public let queueItemId: String?

    enum CodingKeys: String, CodingKey {
        case command
        case mediaUrl = "media_url"
        case queueId = "queue_id"
        case queueItemId = "queue_item_id"
    }

    public enum Command: String, Codable, Sendable {
        case playMedia = "PLAY_MEDIA"
        case stop = "STOP"
        case pause = "PAUSE"
        case unpause = "UNPAUSE"
        case next = "NEXT"
        case previous = "PREVIOUS"
        case unknown

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = Command(rawValue: rawValue) ?? .unknown
        }
    }
}
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter BuiltinPlayerEventTests
```

Expected: PASS

**Step 5: Add test for unknown command**

```swift
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
```

**Step 6: Run test to verify**

```bash
swift test --filter BuiltinPlayerEventTests
```

Expected: PASS

**Step 7: Commit BuiltinPlayerEvent model**

```bash
git add Sources/MusicAssistantKit/Models/BuiltinPlayerEvent.swift \
        Tests/MusicAssistantKitTests/Unit/BuiltinPlayerEventTests.swift
git commit -m "feat: add BuiltinPlayerEvent model for stream URL events

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Add Built-in Player Event Subscription

**Files:**
- Modify: `Sources/MusicAssistantKit/Events/EventPublisher.swift`
- Test: `Tests/MusicAssistantKitTests/Unit/BuiltinPlayerEventPublisherTests.swift`

**Step 1: Write failing test for built-in player event publishing**

```swift
// Tests/MusicAssistantKitTests/Unit/BuiltinPlayerEventPublisherTests.swift
import XCTest
import Combine
@testable import MusicAssistantKit

final class BuiltinPlayerEventPublisherTests: XCTestCase {
    func testBuiltinPlayerEventPublished() throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        var receivedEvent: BuiltinPlayerEvent?
        let cancellable = client.events.builtinPlayerEvents.sink { event in
            receivedEvent = event
        }

        // Simulate BUILTIN_PLAYER event
        mockConnection.simulateEvent("""
        {
            "event": "BUILTIN_PLAYER",
            "data": {
                "command": "PLAY_MEDIA",
                "media_url": "flow/session123/queue456/item789.mp3",
                "queue_id": "queue456",
                "queue_item_id": "item789"
            }
        }
        """)

        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.command, .playMedia)
        XCTAssertEqual(receivedEvent?.mediaUrl, "flow/session123/queue456/item789.mp3")

        cancellable.cancel()
    }

    func testStreamURLConstruction() throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        var constructedURL: URL?
        let cancellable = client.events.builtinPlayerEvents.sink { event in
            if let mediaUrl = event.mediaUrl {
                constructedURL = client.serverInfo?.baseURL.appendingPathComponent(mediaUrl)
            }
        }

        mockConnection.simulateEvent("""
        {
            "event": "BUILTIN_PLAYER",
            "data": {
                "command": "PLAY_MEDIA",
                "media_url": "flow/session123/queue456/item789.mp3"
            }
        }
        """)

        XCTAssertNotNil(constructedURL)
        XCTAssertTrue(constructedURL!.absoluteString.contains("/flow/session123/queue456/item789.mp3"))

        cancellable.cancel()
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter BuiltinPlayerEventPublisherTests
```

Expected: FAIL with "Type 'EventPublisher' has no member 'builtinPlayerEvents'"

**Step 3: Add built-in player event publisher to EventPublisher**

```swift
// Sources/MusicAssistantKit/Events/EventPublisher.swift
// Add new publisher to EventPublisher class

public let builtinPlayerEvents = PassthroughSubject<BuiltinPlayerEvent, Never>()

// In the event routing method, add:
private func routeEvent(_ event: [String: Any]) {
    guard let eventType = event["event"] as? String else { return }

    // ... existing event routing ...

    if eventType == "BUILTIN_PLAYER" {
        if let data = event["data"] as? [String: Any],
           let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let builtinEvent = try? JSONDecoder().decode(BuiltinPlayerEvent.self, from: jsonData) {
            builtinPlayerEvents.send(builtinEvent)
        }
    }

    // ... rest of routing ...
}
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter BuiltinPlayerEventPublisherTests
```

Expected: PASS

**Step 5: Commit event publisher enhancement**

```bash
git add Sources/MusicAssistantKit/Events/EventPublisher.swift \
        Tests/MusicAssistantKitTests/Unit/BuiltinPlayerEventPublisherTests.swift
git commit -m "feat: add built-in player event subscription for stream URLs

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: Stream URL Helper Methods on Client

**Files:**
- Modify: `Sources/MusicAssistantKit/Client/MusicAssistantClient.swift`
- Test: `Tests/MusicAssistantKitTests/Unit/StreamURLHelpersTests.swift`

**Step 1: Write failing test for stream URL helpers**

```swift
// Tests/MusicAssistantKitTests/Unit/StreamURLHelpersTests.swift
import XCTest
@testable import MusicAssistantKit

final class StreamURLHelpersTests: XCTestCase {
    func testGetStreamURLFromMediaPath() throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        // Mock server info with base URL
        let serverInfo = ServerInfo(baseURL: URL(string: "http://192.168.23.196:8095")!)
        // Inject server info into client (implementation detail)

        let streamURL = client.getStreamURL(mediaPath: "flow/session123/queue456/item789.mp3")

        XCTAssertEqual(
            streamURL.url.absoluteString,
            "http://192.168.23.196:8095/flow/session123/queue456/item789.mp3"
        )
    }

    func testConstructQueueStreamURL() throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        let streamURL = client.constructQueueStreamURL(
            sessionId: "session123",
            queueId: "queue456",
            queueItemId: "item789",
            format: .flac,
            flowMode: false
        )

        XCTAssertEqual(
            streamURL.url.absoluteString,
            "http://192.168.23.196:8095/single/session123/queue456/item789.flac"
        )
    }

    func testConstructPreviewURL() throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        let streamURL = client.constructPreviewURL(
            itemId: "track123",
            provider: "library"
        )

        XCTAssertTrue(streamURL.url.absoluteString.contains("/preview?"))
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter StreamURLHelpersTests
```

Expected: FAIL with "Value of type 'MusicAssistantClient' has no member 'getStreamURL'"

**Step 3: Implement stream URL helper methods**

```swift
// Sources/MusicAssistantKit/Client/MusicAssistantClient.swift
// Add these methods to MusicAssistantClient

/// Construct full stream URL from media path received in events
/// - Parameter mediaPath: Media path from BUILTIN_PLAYER event (e.g., "flow/session/queue/item.mp3")
/// - Returns: Complete StreamURL ready for playback
public func getStreamURL(mediaPath: String) -> StreamURL {
    guard let baseURL = serverInfo?.baseURL else {
        fatalError("Server not connected - call connect() first")
    }
    return StreamURL(baseURL: baseURL, mediaPath: mediaPath)
}

/// Construct queue stream URL for specific queue item
/// - Parameters:
///   - sessionId: Active session ID
///   - queueId: Queue ID
///   - queueItemId: Queue item ID
///   - format: Audio format (mp3, flac, pcm)
///   - flowMode: true for gapless flow, false for single item
/// - Returns: StreamURL for the queue item
public func constructQueueStreamURL(
    sessionId: String,
    queueId: String,
    queueItemId: String,
    format: StreamFormat,
    flowMode: Bool = true
) -> StreamURL {
    guard let baseURL = serverInfo?.baseURL else {
        fatalError("Server not connected - call connect() first")
    }
    return StreamURL.queueStream(
        baseURL: baseURL,
        sessionId: sessionId,
        queueId: queueId,
        queueItemId: queueItemId,
        format: format,
        flowMode: flowMode
    )
}

/// Construct preview/clip URL for track
/// - Parameters:
///   - itemId: Track item ID
///   - provider: Provider instance (e.g., "library", "spotify")
/// - Returns: StreamURL for preview audio
public func constructPreviewURL(itemId: String, provider: String) -> StreamURL {
    guard let baseURL = serverInfo?.baseURL else {
        fatalError("Server not connected - call connect() first")
    }
    return StreamURL.preview(baseURL: baseURL, itemId: itemId, provider: provider)
}

/// Construct announcement URL
/// - Parameters:
///   - playerId: Player ID
///   - format: Audio format
///   - preAnnounce: Include pre-announce alert
/// - Returns: StreamURL for announcement
public func constructAnnouncementURL(
    playerId: String,
    format: StreamFormat,
    preAnnounce: Bool = false
) -> StreamURL {
    guard let baseURL = serverInfo?.baseURL else {
        fatalError("Server not connected - call connect() first")
    }
    return StreamURL.announcement(
        baseURL: baseURL,
        playerId: playerId,
        format: format,
        preAnnounce: preAnnounce
    )
}

/// Construct plugin source URL
/// - Parameters:
///   - pluginSource: Plugin source identifier
///   - playerId: Player ID
///   - format: Audio format
/// - Returns: StreamURL for plugin audio
public func constructPluginSourceURL(
    pluginSource: String,
    playerId: String,
    format: StreamFormat
) -> StreamURL {
    guard let baseURL = serverInfo?.baseURL else {
        fatalError("Server not connected - call connect() first")
    }
    return StreamURL.pluginSource(
        baseURL: baseURL,
        pluginSource: pluginSource,
        playerId: playerId,
        format: format
    )
}
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter StreamURLHelpersTests
```

Expected: PASS

**Step 5: Commit helper methods**

```bash
git add Sources/MusicAssistantKit/Client/MusicAssistantClient.swift \
        Tests/MusicAssistantKitTests/Unit/StreamURLHelpersTests.swift
git commit -m "feat: add stream URL construction helper methods to client

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: Update Mock for Testing

**Files:**
- Modify: `Tests/MusicAssistantKitTests/Mocks/MockWebSocketConnection.swift`

**Step 1: Add helper for simulating built-in player events**

```swift
// Tests/MusicAssistantKitTests/Mocks/MockWebSocketConnection.swift

/// Simulate BUILTIN_PLAYER event with media URL
public func simulateBuiltinPlayerEvent(
    command: String,
    mediaUrl: String? = nil,
    queueId: String? = nil,
    queueItemId: String? = nil
) {
    var data: [String: Any] = ["command": command]
    if let mediaUrl = mediaUrl {
        data["media_url"] = mediaUrl
    }
    if let queueId = queueId {
        data["queue_id"] = queueId
    }
    if let queueItemId = queueItemId {
        data["queue_item_id"] = queueItemId
    }

    let event: [String: Any] = [
        "event": "BUILTIN_PLAYER",
        "data": data
    ]

    simulateEvent(event)
}
```

**Step 2: Add test to verify mock helper**

```swift
func testMockBuiltinPlayerEventHelper() throws {
    let mock = MockWebSocketConnection()
    let client = MusicAssistantClient(connection: mock)

    var receivedEvent: BuiltinPlayerEvent?
    let cancellable = client.events.builtinPlayerEvents.sink { event in
        receivedEvent = event
    }

    mock.simulateBuiltinPlayerEvent(
        command: "PLAY_MEDIA",
        mediaUrl: "flow/test/queue/item.mp3",
        queueId: "queue",
        queueItemId: "item"
    )

    XCTAssertNotNil(receivedEvent)
    XCTAssertEqual(receivedEvent?.command, .playMedia)
    XCTAssertEqual(receivedEvent?.mediaUrl, "flow/test/queue/item.mp3")

    cancellable.cancel()
}
```

**Step 3: Run test to verify**

```bash
swift test --filter testMockBuiltinPlayerEventHelper
```

Expected: PASS

**Step 4: Commit mock enhancements**

```bash
git add Tests/MusicAssistantKitTests/Mocks/MockWebSocketConnection.swift
git commit -m "test: add mock helper for built-in player events

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 6: Integration Test with Live Server

**Files:**
- Create: `Tests/MusicAssistantKitTests/Integration/StreamingIntegrationTests.swift`

**Step 1: Write integration test for live streaming**

```swift
// Tests/MusicAssistantKitTests/Integration/StreamingIntegrationTests.swift
import XCTest
import Combine
@testable import MusicAssistantKit

final class StreamingIntegrationTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    func testCaptureBuiltinPlayerEvent() async throws {
        #if SKIP_INTEGRATION_TESTS
        throw XCTSkip("Integration tests disabled")
        #endif

        let host = ProcessInfo.processInfo.environment["MA_TEST_HOST"] ?? "localhost"
        let port = Int(ProcessInfo.processInfo.environment["MA_TEST_PORT"] ?? "8095")!

        let client = MusicAssistantClient(host: host, port: port)
        try await client.connect()

        let eventExpectation = expectation(description: "Receive built-in player event")
        var capturedEvent: BuiltinPlayerEvent?

        client.events.builtinPlayerEvents.sink { event in
            capturedEvent = event
            eventExpectation.fulfill()
        }.store(in: &cancellables)

        // Search for a track
        let results = try await client.search(query: "test")
        guard let track = results.tracks.first else {
            throw XCTSkip("No tracks on server")
        }

        // Get players
        let players = try await client.getPlayers()
        guard let player = players.first else {
            throw XCTSkip("No players available")
        }

        // Start playback
        try await client.playMedia(queueId: player.activeQueue, uri: track.uri)

        // Wait for event
        await fulfillment(of: [eventExpectation], timeout: 5.0)

        // Verify event
        XCTAssertNotNil(capturedEvent)
        XCTAssertEqual(capturedEvent?.command, .playMedia)
        XCTAssertNotNil(capturedEvent?.mediaUrl)

        if let mediaUrl = capturedEvent?.mediaUrl {
            print("Captured media URL: \(mediaUrl)")

            // Construct full stream URL
            let streamURL = client.getStreamURL(mediaPath: mediaUrl)
            print("Full stream URL: \(streamURL.url.absoluteString)")

            // Verify URL is reachable
            let (_, response) = try await URLSession.shared.data(from: streamURL.url)
            let httpResponse = response as! HTTPURLResponse
            XCTAssertEqual(httpResponse.statusCode, 200, "Stream URL should be accessible")
        }

        await client.disconnect()
    }

    func testStreamURLConstruction() async throws {
        #if SKIP_INTEGRATION_TESTS
        throw XCTSkip("Integration tests disabled")
        #endif

        let host = ProcessInfo.processInfo.environment["MA_TEST_HOST"] ?? "localhost"
        let port = Int(ProcessInfo.processInfo.environment["MA_TEST_PORT"] ?? "8095")!

        let client = MusicAssistantClient(host: host, port: port)
        try await client.connect()

        // Test preview URL construction
        let previewURL = client.constructPreviewURL(itemId: "test", provider: "library")
        print("Preview URL: \(previewURL.url.absoluteString)")

        // Note: Preview may return 404 depending on server config
        // This test just verifies URL construction, not endpoint availability

        await client.disconnect()
    }
}
```

**Step 2: Run integration test**

```bash
MA_TEST_HOST=192.168.23.196 MA_TEST_PORT=8095 swift test --filter StreamingIntegrationTests
```

Expected: PASS (or skip if requirements not met)

**Step 3: Commit integration tests**

```bash
git add Tests/MusicAssistantKitTests/Integration/StreamingIntegrationTests.swift
git commit -m "test: add integration tests for streaming URLs

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 7: Documentation

**Files:**
- Create: `docs/streaming-audio-urls.md`
- Modify: `README.md`

**Step 1: Write usage documentation**

```markdown
# Streaming Audio URLs

MusicAssistantKit provides access to Music Assistant's streaming audio endpoints for client-side playback.

## Overview

Music Assistant exposes HTTP streaming endpoints that clients can use for direct audio playback. Stream URLs are obtained through WebSocket events rather than direct queries.

## Architecture

1. **Server sends `BUILTIN_PLAYER` events** containing `media_url` paths
2. **Client constructs full URLs** by combining base URL + media path
3. **Client streams audio** via standard HTTP requests (AVPlayer, URLSession, etc.)

## Getting Stream URLs from Events

Subscribe to built-in player events to receive stream URLs when playback starts:

```swift
import Combine

var cancellables = Set<AnyCancellable>()

client.events.builtinPlayerEvents.sink { event in
    guard event.command == .playMedia,
          let mediaUrl = event.mediaUrl else { return }

    // Construct full stream URL
    let streamURL = client.getStreamURL(mediaPath: mediaUrl)

    // Use with AVPlayer
    let player = AVPlayer(url: streamURL.url)
    player.play()
}.store(in: &cancellables)
```

## Stream URL Types

Music Assistant provides several streaming endpoints:

### 1. Queue Flow Stream (Gapless Playback)

```swift
let streamURL = client.constructQueueStreamURL(
    sessionId: "session-id",
    queueId: "queue-id",
    queueItemId: "item-id",
    format: .mp3,
    flowMode: true  // gapless with crossfade
)
```

URL format: `http://server:8095/flow/{session}/{queue}/{item}.mp3`

### 2. Single Item Stream

```swift
let streamURL = client.constructQueueStreamURL(
    sessionId: "session-id",
    queueId: "queue-id",
    queueItemId: "item-id",
    format: .flac,
    flowMode: false  // single item
)
```

URL format: `http://server:8095/single/{session}/{queue}/{item}.flac`

### 3. Preview/Clip Stream

```swift
let streamURL = client.constructPreviewURL(
    itemId: "track-id",
    provider: "library"
)
```

URL format: `http://server:8095/preview?item_id={double-encoded-id}&provider={provider}`

### 4. Announcement Stream

```swift
let streamURL = client.constructAnnouncementURL(
    playerId: "player-id",
    format: .mp3,
    preAnnounce: true
)
```

URL format: `http://server:8095/announcement/{player}.mp3?pre_announce=true`

### 5. Plugin Source Stream

```swift
let streamURL = client.constructPluginSourceURL(
    pluginSource: "airplay",
    playerId: "player-id",
    format: .flac
)
```

URL format: `http://server:8095/pluginsource/{plugin}/{player}.flac`

## Audio Formats

Supported formats:
- `.mp3` - MP3 audio
- `.flac` - FLAC lossless
- `.pcm` - Raw PCM (requires additional parameters)

## Example: AVPlayer Integration

```swift
import AVFoundation
import Combine

class MusicAssistantPlayer {
    private let client: MusicAssistantClient
    private let avPlayer = AVPlayer()
    private var cancellables = Set<AnyCancellable>()

    init(client: MusicAssistantClient) {
        self.client = client
        setupStreamListener()
    }

    private func setupStreamListener() {
        client.events.builtinPlayerEvents.sink { [weak self] event in
            guard let self = self,
                  event.command == .playMedia,
                  let mediaUrl = event.mediaUrl else { return }

            let streamURL = self.client.getStreamURL(mediaPath: mediaUrl)
            let playerItem = AVPlayerItem(url: streamURL.url)
            self.avPlayer.replaceCurrentItem(with: playerItem)
            self.avPlayer.play()
        }.store(in: &cancellables)
    }

    func pause() {
        avPlayer.pause()
    }

    func resume() {
        avPlayer.play()
    }
}
```

## Session Management

Stream URLs require active playback sessions. The `sessionId` is managed by Music Assistant and included in event data.

**Important:**
- Stream URLs are session-specific
- URLs may expire when sessions end
- Always use fresh URLs from events for reliability

## Limitations

1. **Preview endpoints** may not be enabled on all servers
2. **Session-based URLs** expire - don't cache long-term
3. **DRM content** may have additional restrictions
4. **Format availability** depends on server configuration

## Testing

Run integration tests against a live server:

```bash
MA_TEST_HOST=192.168.23.196 MA_TEST_PORT=8095 swift test --filter StreamingIntegrationTests
```
```

**Step 2: Update README if needed**

Add section to README.md mentioning streaming capabilities:

```markdown
## Features

- WebSocket connection to Music Assistant server
- Player control (play, pause, stop, volume, seek)
- Queue management
- Media search
- **Streaming audio URL access for client-side playback**
- Real-time event subscriptions via Combine
- Comprehensive test coverage
```

**Step 3: Commit documentation**

```bash
git add docs/streaming-audio-urls.md README.md
git commit -m "docs: add streaming audio URLs usage guide

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 8: Final Testing & Verification

**Files:**
- All test files

**Step 1: Run full test suite**

```bash
# Unit tests only
SKIP_INTEGRATION_TESTS=1 swift test
```

Expected: All tests pass

**Step 2: Run with integration tests**

```bash
MA_TEST_HOST=192.168.23.196 MA_TEST_PORT=8095 swift test
```

Expected: All tests pass

**Step 3: Check test coverage**

```bash
swift test --enable-code-coverage
```

Verify coverage meets requirements (≥40%)

**Step 4: Run SwiftLint**

```bash
swiftlint
```

Expected: No violations

**Step 5: Run SwiftFormat**

```bash
swiftformat --lint .
```

Expected: No formatting issues

**Step 6: Final commit if needed**

```bash
git add .
git commit -m "fix: address linting and formatting issues

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Summary

This implementation adds streaming audio URL support through:

1. **StreamURL model** - Constructs URLs for all endpoint types
2. **BuiltinPlayerEvent model** - Parses events containing media URLs
3. **Event subscription** - Publishes built-in player events to subscribers
4. **Helper methods** - Convenient URL construction on MusicAssistantClient
5. **Comprehensive tests** - Unit tests with mocks + integration tests
6. **Documentation** - Usage guide with AVPlayer example

The event-based architecture matches Music Assistant's actual implementation and enables native iOS/macOS audio playback.
