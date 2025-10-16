# Streaming Audio URLs Implementation Plan

> **For Claude:** Use `${SUPERPOWERS_SKILLS_ROOT}/skills/collaboration/executing-plans/SKILL.md` to implement this plan task-by-task.

**Goal:** Add ability to query stream URLs for media items and access them from player events.

**Architecture:** Hybrid approach combining direct queries (`getMediaDetails`) with enhanced player event parsing. Provides three access paths: real-time events, smart cached lookup, and direct queries for arbitrary URIs.

**Tech Stack:** Swift 6.0, WebSocket protocol, Combine publishers, async/await

---

## Discovery Phase

Before implementation, we need to discover the exact WebSocket command format and response structure from Music Assistant. This is critical because we're adding new functionality not currently in the codebase.

### Task 0: API Discovery

**Goal:** Determine the correct WebSocket command and response format for querying media item details.

**Files:**
- Reference: `Sources/MusicAssistantKit/Client/MusicAssistantClient.swift`
- Reference: `Sources/MusicAssistantKit/Models/Messages/ServerInfo.swift`

**Step 1: Check Music Assistant API documentation**

If Music Assistant docs are available, look for:
- Commands related to media item metadata/details
- Stream URL endpoints or WebSocket commands
- Response format examples

**Step 2: Test against live Music Assistant server**

Run exploratory WebSocket commands to discover format:

```bash
# Connect to Music Assistant WebSocket and try these commands:
# Option 1: music/get_item
# Option 2: music/item_details
# Option 3: music/stream_details

# Example test message:
{
  "message_id": "test-1",
  "command": "music/get_item",
  "args": {
    "uri": "library://track/<some-id>"
  }
}
```

**Step 3: Inspect player_updated events**

Connect to live server, start playback, capture `player_updated` event:
- Check if `current_item` contains stream URLs
- Check if there's a separate `stream_details` or `stream_options` field
- Document exact JSON structure

**Step 4: Document findings**

Create `docs/api-discovery-streaming.md` with:
- Exact command format
- Example request/response
- Field mappings for StreamOption properties
- Any provider-specific variations observed

**Expected Outcome:** Clear documentation of API format to implement against.

---

## Implementation Phase

### Task 1: Core Data Models

**Files:**
- Create: `Sources/MusicAssistantKit/Models/StreamOption.swift`
- Create: `Sources/MusicAssistantKit/Models/MediaDetails.swift`
- Test: `Tests/MusicAssistantKitTests/Unit/StreamOptionTests.swift`

**Step 1: Write failing test for StreamOption decoding**

```swift
// Tests/MusicAssistantKitTests/Unit/StreamOptionTests.swift
import XCTest
@testable import MusicAssistantKit

final class StreamOptionTests: XCTestCase {
    func testDecodeStreamOption() throws {
        let json = """
        {
            "url": "http://localhost:8095/stream/track/123",
            "quality": "lossless",
            "format": "flac",
            "bitrate": 1411,
            "sample_rate": 44100,
            "channels": 2,
            "provider": "local"
        }
        """.data(using: .utf8)!

        let option = try JSONDecoder().decode(StreamOption.self, from: json)

        XCTAssertEqual(option.url.absoluteString, "http://localhost:8095/stream/track/123")
        XCTAssertEqual(option.quality, .lossless)
        XCTAssertEqual(option.format, .flac)
        XCTAssertEqual(option.bitrate, 1411)
        XCTAssertEqual(option.sampleRate, 44100)
        XCTAssertEqual(option.channels, 2)
        XCTAssertEqual(option.provider, "local")
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter StreamOptionTests
```

Expected: FAIL with "Type 'StreamOption' not found"

**Step 3: Implement StreamOption model**

```swift
// Sources/MusicAssistantKit/Models/StreamOption.swift
// ABOUTME: Represents a single stream option with quality/format details
// ABOUTME: Returned by Music Assistant for available audio streams

import Foundation

public struct StreamOption: Codable, Equatable, Sendable {
    public let url: URL
    public let quality: StreamQuality
    public let format: AudioFormat
    public let bitrate: Int?
    public let sampleRate: Int?
    public let channels: Int?
    public let provider: String

    enum CodingKeys: String, CodingKey {
        case url
        case quality
        case format
        case bitrate
        case sampleRate = "sample_rate"
        case channels
        case provider
    }
}

public enum StreamQuality: String, Codable, Sendable {
    case lossy
    case lossless
    case hiRes = "hi_res"
    case unknown
}

public enum AudioFormat: String, Codable, Sendable {
    case mp3
    case aac
    case flac
    case alac
    case ogg
    case wav
    case unknown
}
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter StreamOptionTests
```

Expected: PASS

**Step 5: Add tests for edge cases**

```swift
func testDecodeStreamOptionWithMissingOptionalFields() throws {
    let json = """
    {
        "url": "http://localhost:8095/stream/track/123",
        "quality": "lossy",
        "format": "mp3",
        "provider": "spotify"
    }
    """.data(using: .utf8)!

    let option = try JSONDecoder().decode(StreamOption.self, from: json)

    XCTAssertNil(option.bitrate)
    XCTAssertNil(option.sampleRate)
    XCTAssertNil(option.channels)
}

func testDecodeUnknownQualityAndFormat() throws {
    let json = """
    {
        "url": "http://localhost:8095/stream/track/123",
        "quality": "ultra_mega_quality",
        "format": "newfangled_format",
        "provider": "custom"
    }
    """.data(using: .utf8)!

    let option = try JSONDecoder().decode(StreamOption.self, from: json)

    XCTAssertEqual(option.quality, .unknown)
    XCTAssertEqual(option.format, .unknown)
}
```

**Step 6: Run tests to verify**

```bash
swift test --filter StreamOptionTests
```

Expected: PASS (all tests)

**Step 7: Commit StreamOption model**

```bash
git add Sources/MusicAssistantKit/Models/StreamOption.swift \
        Tests/MusicAssistantKitTests/Unit/StreamOptionTests.swift
git commit -m "feat: add StreamOption model with quality and format enums

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: MediaDetails Model

**Files:**
- Create: `Sources/MusicAssistantKit/Models/MediaDetails.swift`
- Test: `Tests/MusicAssistantKitTests/Unit/MediaDetailsTests.swift`

**Step 1: Write failing test for MediaDetails decoding**

```swift
// Tests/MusicAssistantKitTests/Unit/MediaDetailsTests.swift
import XCTest
@testable import MusicAssistantKit

final class MediaDetailsTests: XCTestCase {
    func testDecodeMediaDetails() throws {
        let json = """
        {
            "uri": "library://track/123",
            "name": "Test Track",
            "artists": [
                {"name": "Test Artist", "uri": "library://artist/1"}
            ],
            "album": "Test Album",
            "duration": 180,
            "image_url": "http://localhost:8095/image/track/123",
            "provider": "local",
            "stream_options": [
                {
                    "url": "http://localhost:8095/stream/track/123",
                    "quality": "lossless",
                    "format": "flac",
                    "provider": "local"
                }
            ]
        }
        """.data(using: .utf8)!

        let details = try JSONDecoder().decode(MediaDetails.self, from: json)

        XCTAssertEqual(details.uri, "library://track/123")
        XCTAssertEqual(details.name, "Test Track")
        XCTAssertEqual(details.artists?.count, 1)
        XCTAssertEqual(details.album, "Test Album")
        XCTAssertEqual(details.duration, 180)
        XCTAssertEqual(details.provider, "local")
        XCTAssertEqual(details.streamOptions.count, 1)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter MediaDetailsTests
```

Expected: FAIL with "Type 'MediaDetails' not found"

**Step 3: Implement MediaDetails model**

```swift
// Sources/MusicAssistantKit/Models/MediaDetails.swift
// ABOUTME: Full metadata for a media item including available streams
// ABOUTME: Returned by getMediaDetails WebSocket command

import Foundation

public struct MediaDetails: Codable, Equatable, Sendable {
    public let uri: String
    public let name: String
    public let artists: [Artist]?
    public let album: String?
    public let duration: Int?
    public let imageUrl: URL?
    public let provider: String
    public let streamOptions: [StreamOption]

    enum CodingKeys: String, CodingKey {
        case uri
        case name
        case artists
        case album
        case duration
        case imageUrl = "image_url"
        case provider
        case streamOptions = "stream_options"
    }
}
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter MediaDetailsTests
```

Expected: PASS

**Step 5: Add test for minimal response**

```swift
func testDecodeMediaDetailsMinimal() throws {
    let json = """
    {
        "uri": "spotify://track/abc",
        "name": "Minimal Track",
        "provider": "spotify",
        "stream_options": []
    }
    """.data(using: .utf8)!

    let details = try JSONDecoder().decode(MediaDetails.self, from: json)

    XCTAssertEqual(details.uri, "spotify://track/abc")
    XCTAssertNil(details.artists)
    XCTAssertNil(details.album)
    XCTAssertNil(details.duration)
    XCTAssertNil(details.imageUrl)
    XCTAssertEqual(details.streamOptions.count, 0)
}
```

**Step 6: Run test to verify**

```bash
swift test --filter MediaDetailsTests
```

Expected: PASS

**Step 7: Commit MediaDetails model**

```bash
git add Sources/MusicAssistantKit/Models/MediaDetails.swift \
        Tests/MusicAssistantKitTests/Unit/MediaDetailsTests.swift
git commit -m "feat: add MediaDetails model with stream options

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Add getMediaDetails Command

**Files:**
- Modify: `Sources/MusicAssistantKit/Client/MusicAssistantClient.swift`
- Test: `Tests/MusicAssistantKitTests/Unit/ClientCommandTests.swift` (or create new)

**Step 1: Write failing test for getMediaDetails**

```swift
// Tests/MusicAssistantKitTests/Unit/ClientCommandTests.swift
func testGetMediaDetails() async throws {
    let mockConnection = MockWebSocketConnection()
    let client = MusicAssistantClient(connection: mockConnection)

    // Setup mock response based on API discovery findings
    mockConnection.queueResponse("""
    {
        "message_id": "test-1",
        "result": {
            "uri": "library://track/123",
            "name": "Test Track",
            "provider": "local",
            "stream_options": [
                {
                    "url": "http://localhost:8095/stream/track/123",
                    "quality": "lossless",
                    "format": "flac",
                    "provider": "local"
                }
            ]
        }
    }
    """)

    let details = try await client.getMediaDetails(uri: "library://track/123")

    XCTAssertEqual(details.uri, "library://track/123")
    XCTAssertEqual(details.name, "Test Track")
    XCTAssertEqual(details.streamOptions.count, 1)

    // Verify correct command was sent
    let sentCommand = try XCTUnwrap(mockConnection.lastSentMessage)
    XCTAssertTrue(sentCommand.contains("\"command\":\"music/get_item\""))
    XCTAssertTrue(sentCommand.contains("\"uri\":\"library://track/123\""))
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter testGetMediaDetails
```

Expected: FAIL with "Value of type 'MusicAssistantClient' has no member 'getMediaDetails'"

**Step 3: Implement getMediaDetails method**

```swift
// Sources/MusicAssistantKit/Client/MusicAssistantClient.swift
// Add this method to MusicAssistantClient

/// Get full metadata and stream options for a media item
/// - Parameter uri: Media URI (e.g., "library://track/123", "spotify://track/abc")
/// - Returns: MediaDetails including available stream URLs
/// - Throws: If command fails or URI is invalid
public func getMediaDetails(uri: String) async throws -> MediaDetails {
    try await sendCommand("music/get_item", ["uri": uri])
}
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter testGetMediaDetails
```

Expected: PASS

**Step 5: Add error handling test**

```swift
func testGetMediaDetailsInvalidURI() async throws {
    let mockConnection = MockWebSocketConnection()
    let client = MusicAssistantClient(connection: mockConnection)

    mockConnection.queueError("Invalid URI")

    do {
        _ = try await client.getMediaDetails(uri: "invalid://bad")
        XCTFail("Expected error to be thrown")
    } catch {
        // Expected
    }
}
```

**Step 6: Run test to verify**

```bash
swift test --filter testGetMediaDetailsInvalidURI
```

Expected: PASS

**Step 7: Commit getMediaDetails command**

```bash
git add Sources/MusicAssistantKit/Client/MusicAssistantClient.swift \
        Tests/MusicAssistantKitTests/Unit/ClientCommandTests.swift
git commit -m "feat: add getMediaDetails command to query stream URLs

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: Enhance Player State with Stream Options

**Files:**
- Modify: `Sources/MusicAssistantKit/Events/EventPublisher.swift`
- Create: `Tests/MusicAssistantKitTests/Unit/PlayerEventStreamTests.swift`

**Step 1: Write failing test for parsing stream options from player event**

```swift
// Tests/MusicAssistantKitTests/Unit/PlayerEventStreamTests.swift
import XCTest
import Combine
@testable import MusicAssistantKit

final class PlayerEventStreamTests: XCTestCase {
    func testPlayerEventWithStreamOptions() throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        var receivedUpdate: (String, [String: Any])?
        let cancellable = client.events.playerUpdates.sink { playerId, data in
            receivedUpdate = (playerId, data)
        }

        // Send player_updated event with stream_options
        mockConnection.simulateEvent("""
        {
            "event": "player_updated",
            "data": {
                "player_id": "player1",
                "state": "playing",
                "current_item": {
                    "uri": "library://track/123",
                    "name": "Test Track"
                },
                "stream_options": [
                    {
                        "url": "http://localhost:8095/stream/track/123",
                        "quality": "lossless",
                        "format": "flac",
                        "provider": "local"
                    }
                ]
            }
        }
        """)

        XCTAssertNotNil(receivedUpdate)
        XCTAssertEqual(receivedUpdate?.0, "player1")

        let streamOptions = receivedUpdate?.1["stream_options"] as? [[String: Any]]
        XCTAssertNotNil(streamOptions)
        XCTAssertEqual(streamOptions?.count, 1)

        cancellable.cancel()
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter testPlayerEventWithStreamOptions
```

Expected: FAIL (stream_options not parsed or nil)

**Step 3: Update EventPublisher to preserve stream_options**

```swift
// Sources/MusicAssistantKit/Events/EventPublisher.swift
// Locate the player_updated event handling and ensure stream_options
// is included in the data dictionary passed to playerUpdates publisher

// The exact implementation depends on current event parsing logic
// Ensure that when routing player_updated events, we preserve
// the stream_options field from the event data
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter testPlayerEventWithStreamOptions
```

Expected: PASS

**Step 5: Add test for event without stream options**

```swift
func testPlayerEventWithoutStreamOptions() throws {
    let mockConnection = MockWebSocketConnection()
    let client = MusicAssistantClient(connection: mockConnection)

    var receivedUpdate: (String, [String: Any])?
    let cancellable = client.events.playerUpdates.sink { playerId, data in
        receivedUpdate = (playerId, data)
    }

    mockConnection.simulateEvent("""
    {
        "event": "player_updated",
        "data": {
            "player_id": "player1",
            "state": "playing"
        }
    }
    """)

    XCTAssertNotNil(receivedUpdate)
    let streamOptions = receivedUpdate?.1["stream_options"]
    XCTAssertNil(streamOptions)

    cancellable.cancel()
}
```

**Step 6: Run test to verify**

```bash
swift test --filter PlayerEventStreamTests
```

Expected: PASS (all tests)

**Step 7: Commit event enhancement**

```bash
git add Sources/MusicAssistantKit/Events/EventPublisher.swift \
        Tests/MusicAssistantKitTests/Unit/PlayerEventStreamTests.swift
git commit -m "feat: preserve stream_options in player_updated events

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: Add getCurrentStreamOptions Convenience Method

**Files:**
- Modify: `Sources/MusicAssistantKit/Client/MusicAssistantClient.swift`
- Test: `Tests/MusicAssistantKitTests/Unit/StreamOptionsTests.swift`

**Step 1: Write failing test for getCurrentStreamOptions**

```swift
// Tests/MusicAssistantKitTests/Unit/StreamOptionsTests.swift
import XCTest
@testable import MusicAssistantKit

final class StreamOptionsTests: XCTestCase {
    func testGetCurrentStreamOptionsFromCache() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)

        // Simulate player state with stream options in cache
        mockConnection.simulateEvent("""
        {
            "event": "player_updated",
            "data": {
                "player_id": "player1",
                "state": "playing",
                "current_item": {
                    "uri": "library://track/123"
                },
                "stream_options": [
                    {
                        "url": "http://localhost:8095/stream/track/123",
                        "quality": "lossless",
                        "format": "flac",
                        "provider": "local"
                    }
                ]
            }
        }
        """)

        // Should return cached stream options without querying
        let options = try await client.getCurrentStreamOptions(playerId: "player1")

        XCTAssertNotNil(options)
        XCTAssertEqual(options?.count, 1)
        XCTAssertEqual(options?.first?.quality, .lossless)

        // Verify no additional command was sent
        XCTAssertNil(mockConnection.lastSentMessage)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter testGetCurrentStreamOptionsFromCache
```

Expected: FAIL with "Value of type 'MusicAssistantClient' has no member 'getCurrentStreamOptions'"

**Step 3: Implement getCurrentStreamOptions method**

```swift
// Sources/MusicAssistantKit/Client/MusicAssistantClient.swift

/// Get stream options for currently playing media on a player
/// Checks cached player state first, queries if needed
/// - Parameters:
///   - playerId: Player ID
///   - forceRefresh: If true, bypass cache and query fresh data
/// - Returns: Array of available stream options, or nil if player not playing
/// - Throws: If query fails (when cache miss occurs)
public func getCurrentStreamOptions(
    playerId: String,
    forceRefresh: Bool = false
) async throws -> [StreamOption]? {
    // Try cache first if not forcing refresh
    if !forceRefresh, let cached = getCachedStreamOptions(playerId: playerId) {
        return cached
    }

    // Fall back to querying current media item
    // This requires getting player state to find current URI
    // Then calling getMediaDetails with that URI

    // Note: Implementation depends on how player state is accessed
    // May need to add a getPlayerState method if not present
    // Placeholder implementation:

    // Get player state (assumes this method exists or needs to be added)
    // let playerState = try await getPlayer(playerId: playerId)
    // guard let currentUri = playerState.currentItemUri else {
    //     return nil
    // }

    // let details = try await getMediaDetails(uri: currentUri)
    // return details.streamOptions

    // For now, return nil - will implement after confirming player state access
    return nil
}

private func getCachedStreamOptions(playerId: String) -> [StreamOption]? {
    // TODO: Access most recent player_updated event data for this player
    // Parse stream_options from cached data
    // Return nil if not in cache or no stream_options present
    return nil
}
```

**Step 4: Run test to verify baseline**

```bash
swift test --filter testGetCurrentStreamOptionsFromCache
```

Expected: Still fails, but compiles

**Step 5: Implement cache lookup logic**

This requires understanding how EventPublisher stores recent events. Options:
1. Add a cache dictionary in EventPublisher keyed by player ID
2. Store last event data in MusicAssistantClient
3. Require consumers to maintain their own cache from subscriptions

For simplicity, implement option 2: store last player event per player ID.

```swift
// Add to MusicAssistantClient:
private var playerStateCache: [String: [String: Any]] = [:]

// In event handling (where playerUpdates publishes):
// Update cache when player_updated events arrive
// playerStateCache[playerId] = eventData

// Update getCachedStreamOptions:
private func getCachedStreamOptions(playerId: String) -> [StreamOption]? {
    guard let cachedData = playerStateCache[playerId],
          let streamOptionsData = cachedData["stream_options"] as? [[String: Any]] else {
        return nil
    }

    // Parse stream options from raw data
    return streamOptionsData.compactMap { dict -> StreamOption? in
        guard let urlString = dict["url"] as? String,
              let url = URL(string: urlString),
              let qualityString = dict["quality"] as? String,
              let formatString = dict["format"] as? String,
              let provider = dict["provider"] as? String else {
            return nil
        }

        let quality = StreamQuality(rawValue: qualityString) ?? .unknown
        let format = AudioFormat(rawValue: formatString) ?? .unknown

        return StreamOption(
            url: url,
            quality: quality,
            format: format,
            bitrate: dict["bitrate"] as? Int,
            sampleRate: dict["sample_rate"] as? Int,
            channels: dict["channels"] as? Int,
            provider: provider
        )
    }
}
```

**Step 6: Run test to verify it passes**

```bash
swift test --filter testGetCurrentStreamOptionsFromCache
```

Expected: PASS

**Step 7: Add test for cache miss (fallback to query)**

```swift
func testGetCurrentStreamOptionsFallbackToQuery() async throws {
    let mockConnection = MockWebSocketConnection()
    let client = MusicAssistantClient(connection: mockConnection)

    // No cached data, should fall back to query
    // Need to mock both getPlayer and getMediaDetails responses

    mockConnection.queueResponse("""
    {
        "message_id": "1",
        "result": {
            "player_id": "player1",
            "current_item": {
                "uri": "library://track/123"
            }
        }
    }
    """)

    mockConnection.queueResponse("""
    {
        "message_id": "2",
        "result": {
            "uri": "library://track/123",
            "name": "Test Track",
            "provider": "local",
            "stream_options": [
                {
                    "url": "http://localhost:8095/stream/track/123",
                    "quality": "lossless",
                    "format": "flac",
                    "provider": "local"
                }
            ]
        }
    }
    """)

    let options = try await client.getCurrentStreamOptions(playerId: "player1")

    XCTAssertNotNil(options)
    XCTAssertEqual(options?.count, 1)
}
```

**Step 8: Complete fallback implementation**

```swift
// Update getCurrentStreamOptions to implement fallback logic
public func getCurrentStreamOptions(
    playerId: String,
    forceRefresh: Bool = false
) async throws -> [StreamOption]? {
    if !forceRefresh, let cached = getCachedStreamOptions(playerId: playerId) {
        return cached
    }

    // Assumes getPlayer method exists - may need to implement
    let player = try await getPlayer(playerId: playerId)
    guard let currentUri = player.currentItemUri else {
        return nil
    }

    let details = try await getMediaDetails(uri: currentUri)
    return details.streamOptions
}
```

**Step 9: Run tests to verify**

```bash
swift test --filter StreamOptionsTests
```

Expected: PASS (all tests)

**Step 10: Commit convenience method**

```bash
git add Sources/MusicAssistantKit/Client/MusicAssistantClient.swift \
        Tests/MusicAssistantKitTests/Unit/StreamOptionsTests.swift
git commit -m "feat: add getCurrentStreamOptions with smart caching

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 6: Update Mock for Testing

**Files:**
- Modify: `Tests/MusicAssistantKitTests/Mocks/MockWebSocketConnection.swift`

**Step 1: Add helpers for streaming tests**

```swift
// Tests/MusicAssistantKitTests/Mocks/MockWebSocketConnection.swift

// Add method to queue media details response
func queueMediaDetailsResponse(uri: String, streamOptions: [[String: Any]]) {
    let response = """
    {
        "message_id": "\(UUID().uuidString)",
        "result": {
            "uri": "\(uri)",
            "name": "Mock Track",
            "provider": "mock",
            "stream_options": \(jsonArray(streamOptions))
        }
    }
    """
    queueResponse(response)
}

// Add method to simulate player event with stream options
func simulatePlayerEventWithStreams(playerId: String, streamOptions: [[String: Any]]) {
    let event = """
    {
        "event": "player_updated",
        "data": {
            "player_id": "\(playerId)",
            "state": "playing",
            "current_item": {
                "uri": "library://track/123"
            },
            "stream_options": \(jsonArray(streamOptions))
        }
    }
    """
    simulateEvent(event)
}

private func jsonArray(_ array: [[String: Any]]) -> String {
    // Helper to serialize array to JSON string
    // Implementation depends on existing mock utilities
}
```

**Step 2: Add test to verify mock helpers work**

```swift
func testMockMediaDetailsHelper() throws {
    let mock = MockWebSocketConnection()

    mock.queueMediaDetailsResponse(
        uri: "test://track/1",
        streamOptions: [
            [
                "url": "http://test.local/stream",
                "quality": "lossless",
                "format": "flac",
                "provider": "test"
            ]
        ]
    )

    // Verify response can be received and parsed
    // (depends on existing mock test patterns)
}
```

**Step 3: Run test to verify**

```bash
swift test --filter testMockMediaDetailsHelper
```

Expected: PASS

**Step 4: Commit mock enhancements**

```bash
git add Tests/MusicAssistantKitTests/Mocks/MockWebSocketConnection.swift
git commit -m "test: add mock helpers for stream option testing

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 7: Integration Test

**Files:**
- Create: `Tests/MusicAssistantKitTests/Integration/StreamingIntegrationTests.swift`

**Step 1: Write integration test for real server**

```swift
// Tests/MusicAssistantKitTests/Integration/StreamingIntegrationTests.swift
import XCTest
@testable import MusicAssistantKit

final class StreamingIntegrationTests: XCTestCase {
    func testGetMediaDetailsRealServer() async throws {
        #if SKIP_INTEGRATION_TESTS
        throw XCTSkip("Integration tests disabled")
        #endif

        let host = ProcessInfo.processInfo.environment["MA_TEST_HOST"] ?? "localhost"
        let port = Int(ProcessInfo.processInfo.environment["MA_TEST_PORT"] ?? "8095")!

        let client = MusicAssistantClient(host: host, port: port)
        try await client.connect()

        // Get a known track URI from the test server
        // This may need adjustment based on your test server's content
        let searchResults = try await client.search(query: "test")
        guard let firstTrack = searchResults.tracks.first else {
            throw XCTSkip("No tracks available on test server")
        }

        // Query stream details
        let details = try await client.getMediaDetails(uri: firstTrack.uri)

        XCTAssertEqual(details.uri, firstTrack.uri)
        XCTAssertFalse(details.streamOptions.isEmpty, "Expected at least one stream option")

        // Verify stream URLs are valid
        for option in details.streamOptions {
            XCTAssertTrue(option.url.absoluteString.hasPrefix("http"))
        }

        await client.disconnect()
    }

    func testGetCurrentStreamOptionsRealServer() async throws {
        #if SKIP_INTEGRATION_TESTS
        throw XCTSkip("Integration tests disabled")
        #endif

        let host = ProcessInfo.processInfo.environment["MA_TEST_HOST"] ?? "localhost"
        let port = Int(ProcessInfo.processInfo.environment["MA_TEST_PORT"] ?? "8095")!

        let client = MusicAssistantClient(host: host, port: port)
        try await client.connect()

        // Get available players
        let players = try await client.getPlayers()
        guard let firstPlayer = players.first else {
            throw XCTSkip("No players available on test server")
        }

        // Play something
        let searchResults = try await client.search(query: "test")
        guard let firstTrack = searchResults.tracks.first else {
            throw XCTSkip("No tracks available on test server")
        }

        try await client.playMedia(
            queueId: firstPlayer.activeQueue,
            uri: firstTrack.uri
        )

        // Wait a moment for playback to start
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Get current stream options
        let options = try await client.getCurrentStreamOptions(playerId: firstPlayer.playerId)

        XCTAssertNotNil(options, "Expected stream options for playing track")

        await client.disconnect()
    }
}
```

**Step 2: Run integration test against real server**

```bash
MA_TEST_HOST=localhost MA_TEST_PORT=8095 swift test --filter StreamingIntegrationTests
```

Expected: PASS (or skip if server not available)

**Step 3: Commit integration tests**

```bash
git add Tests/MusicAssistantKitTests/Integration/StreamingIntegrationTests.swift
git commit -m "test: add integration tests for streaming URLs

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 8: Documentation

**Files:**
- Create: `docs/streaming-audio-urls.md`
- Modify: `README.md` (if appropriate)

**Step 1: Write usage documentation**

```markdown
# Streaming Audio URLs

MusicAssistantKit provides three ways to access audio stream URLs:

## 1. Query Any Media Item

Get stream details for any media URI:

\```swift
let details = try await client.getMediaDetails(uri: "library://track/123")

for option in details.streamOptions {
    print("Quality: \(option.quality)")
    print("Format: \(option.format)")
    print("URL: \(option.url)")
    print("Bitrate: \(option.bitrate ?? 0) kbps")
}
\```

## 2. Subscribe to Player Events

Stream options are included in player update events:

\```swift
client.events.playerUpdates.sink { playerId, data in
    if let streamOptions = data["stream_options"] as? [[String: Any]] {
        // Parse stream options from event data
    }
}.store(in: &cancellables)
\```

## 3. Get Current Player Streams (Convenience)

Smart lookup with caching:

\```swift
let options = try await client.getCurrentStreamOptions(playerId: "player1")

// Force refresh bypassing cache
let fresh = try await client.getCurrentStreamOptions(
    playerId: "player1",
    forceRefresh: true
)
\```

## Stream Option Properties

- `url: URL` - Direct HTTP URL for streaming
- `quality: StreamQuality` - `.lossy`, `.lossless`, `.hiRes`, or `.unknown`
- `format: AudioFormat` - `.mp3`, `.flac`, `.aac`, etc.
- `bitrate: Int?` - Bitrate in kbps (if available)
- `sampleRate: Int?` - Sample rate in Hz (if available)
- `channels: Int?` - Channel count (1=mono, 2=stereo, etc.)
- `provider: String` - Source provider ("local", "spotify", etc.)

## Provider Limitations

Not all providers expose stream URLs:
- DRM-protected content may return empty `streamOptions`
- Some streaming services provide playback through their own SDKs
- Stream URLs may be time-limited (don't cache long-term)

## Example: Playing with AVPlayer

\```swift
import AVFoundation

let details = try await client.getMediaDetails(uri: trackUri)

guard let bestStream = details.streamOptions.first(where: { $0.quality == .lossless })
      ?? details.streamOptions.first else {
    print("No streams available")
    return
}

let player = AVPlayer(url: bestStream.url)
player.play()
\```
```

**Step 2: Commit documentation**

```bash
git add docs/streaming-audio-urls.md
git commit -m "docs: add streaming audio URLs usage guide

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 9: Final Testing & Verification

**Files:**
- All test files

**Step 1: Run full test suite**

```bash
# Unit tests only (fast)
SKIP_INTEGRATION_TESTS=1 swift test
```

Expected: All tests pass

**Step 2: Run with integration tests**

```bash
# Full test suite including integration
MA_TEST_HOST=localhost MA_TEST_PORT=8095 swift test
```

Expected: All tests pass (or integration skipped if server unavailable)

**Step 3: Check test coverage**

```bash
swift test --enable-code-coverage
```

Verify coverage meets project requirements (≥40% per CLAUDE.md)

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

**Step 6: Final commit if any fixes needed**

```bash
git add .
git commit -m "fix: address linting and formatting issues

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Notes

### API Discovery Dependency

Task 0 is critical - we need to discover:
1. Exact WebSocket command for querying media details
2. Response structure and field names
3. Whether stream options appear in player events

Implementation Tasks 1-9 assume API discovery is complete. Adjust models and commands based on actual API findings.

### Testing Approach

- Focus on unit tests with mocks (fast, no dependencies)
- Minimal integration tests to verify real-world behavior
- Follow TDD: test → fail → implement → pass → commit

### Error Handling

All async methods should throw on:
- Invalid URIs
- Network failures
- Unsupported commands (older Music Assistant versions)
- Malformed responses

Return empty arrays (not nil) when stream options unavailable to distinguish "no streams" from "data not present".

### Performance Considerations

- `getCurrentStreamOptions` uses caching to avoid redundant queries
- Stream URLs may be time-limited - document that consumers should not cache long-term
- Player state cache should be thread-safe if accessed from multiple contexts
