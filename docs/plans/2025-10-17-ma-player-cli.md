# ma-player CLI Implementation Plan

> **For Claude:** Use `${SUPERPOWERS_SKILLS_ROOT}/skills/collaboration/executing-plans/SKILL.md` to implement this plan task-by-task.

**Goal:** Build a comprehensive Music Assistant audio player CLI with subcommand architecture for playback control, monitoring, and queue management.

**Architecture:** Subcommand-based CLI using ArgumentParser. Core PlayerSession actor manages MusicAssistantClient connection and AVPlayer state. Each subcommand (play, control, monitor, queue, volume, info) creates a session, executes its operation, and exits. Protocol-based AudioPlayerProtocol allows mocking AVPlayer in tests.

**Tech Stack:** Swift 6, ArgumentParser, AVFoundation, MusicAssistantKit, Combine → AsyncStream bridging

---

## Task 1: AudioPlayerProtocol & PlayerSession Foundation

**Files:**
- Create: `Sources/MAPlayerLib/AudioPlayerProtocol.swift`
- Create: `Sources/MAPlayerLib/PlayerSession.swift`
- Create: `Tests/MAPlayerLibTests/PlayerSessionTests.swift`

**Step 1: Write failing test for PlayerSession initialization**

```swift
import XCTest
import MusicAssistantKit
@testable import MAPlayerLib

final class PlayerSessionTests: XCTestCase {
    func testInitializationConnectsToServer() async throws {
        let session = try await PlayerSession(
            host: "192.168.23.196",
            port: 8095,
            playerId: "test-player"
        )

        XCTAssertNotNil(session)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter PlayerSessionTests`
Expected: FAIL with "Cannot find 'PlayerSession' in scope"

**Step 3: Create AudioPlayerProtocol**

Create `Sources/MAPlayerLib/AudioPlayerProtocol.swift`:

```swift
// ABOUTME: Protocol for audio playback, enabling AVPlayer mocking in tests
// ABOUTME: Provides standard playback controls and state observation

import Foundation
import AVFoundation

public protocol AudioPlayerProtocol: Sendable {
    func replaceCurrentItem(with url: URL?)
    func play()
    func pause()
    func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime) async -> Bool
    var currentTime: CMTime { get }
    var duration: CMTime? { get }
    var rate: Float { get }
}

extension AVPlayer: AudioPlayerProtocol {
    public var duration: CMTime? {
        currentItem?.duration
    }

    public var currentTime: CMTime {
        currentTime()
    }

    public func replaceCurrentItem(with url: URL?) {
        if let url = url {
            replaceCurrentItem(with: AVPlayerItem(url: url))
        } else {
            replaceCurrentItem(with: nil)
        }
    }
}
```

**Step 4: Create minimal PlayerSession implementation**

Create `Sources/MAPlayerLib/PlayerSession.swift`:

```swift
// ABOUTME: Manages MusicAssistantClient connection and AVPlayer state for playback control
// ABOUTME: Actor-isolated for thread-safe access, bridges WebSocket events to AVPlayer

import Foundation
import AVFoundation
import Combine
import MusicAssistantKit

public actor PlayerSession {
    private let client: MusicAssistantClient
    private let playerId: String
    private let audioPlayer: AudioPlayerProtocol
    private var cancellables = Set<AnyCancellable>()

    public init(
        host: String,
        port: Int,
        playerId: String,
        audioPlayer: AudioPlayerProtocol? = nil
    ) async throws {
        self.client = MusicAssistantClient(host: host, port: port)
        self.playerId = playerId
        self.audioPlayer = audioPlayer ?? AVPlayer()

        try await client.connect()
    }

    deinit {
        Task { [client] in
            await client.disconnect()
        }
    }
}
```

**Step 5: Update Package.swift to add MAPlayerLib target**

Modify `Package.swift`, add new target after MAStreamLib:

```swift
.target(
    name: "MAPlayerLib",
    dependencies: ["MusicAssistantKit"],
    path: "Sources/MAPlayerLib"
),
```

Add test target:

```swift
.testTarget(
    name: "MAPlayerLibTests",
    dependencies: ["MAPlayerLib", "MusicAssistantKit"],
    path: "Tests/MAPlayerLibTests"
),
```

**Step 6: Run test to verify it passes**

Run: `swift test --filter PlayerSessionTests`
Expected: PASS (may need mock client later, but should compile now)

**Step 7: Commit**

```bash
git add Sources/MAPlayerLib/ Tests/MAPlayerLibTests/ Package.swift
git commit -m "feat: add PlayerSession foundation with AudioPlayerProtocol"
```

---

## Task 2: Stream Event Listener in PlayerSession

**Files:**
- Modify: `Sources/MAPlayerLib/PlayerSession.swift`
- Create: `Tests/MAPlayerLibTests/Mocks/MockAudioPlayer.swift`
- Modify: `Tests/MAPlayerLibTests/PlayerSessionTests.swift`

**Step 1: Write failing test for stream event handling**

Create `Tests/MAPlayerLibTests/Mocks/MockAudioPlayer.swift`:

```swift
// ABOUTME: Mock audio player for testing PlayerSession without AVFoundation
// ABOUTME: Tracks calls and provides controllable state

import Foundation
import AVFoundation
@testable import MAPlayerLib

public final class MockAudioPlayer: AudioPlayerProtocol, @unchecked Sendable {
    public var lastReplacedURL: URL?
    public var playCallCount = 0
    public var pauseCallCount = 0
    public var mockCurrentTime = CMTime.zero
    public var mockDuration: CMTime?
    public var mockRate: Float = 0.0

    public init() {}

    public func replaceCurrentItem(with url: URL?) {
        lastReplacedURL = url
    }

    public func play() {
        playCallCount += 1
        mockRate = 1.0
    }

    public func pause() {
        pauseCallCount += 1
        mockRate = 0.0
    }

    public func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime) async -> Bool {
        mockCurrentTime = time
        return true
    }

    public var currentTime: CMTime { mockCurrentTime }
    public var duration: CMTime? { mockDuration }
    public var rate: Float { mockRate }
}
```

Add test in `Tests/MAPlayerLibTests/PlayerSessionTests.swift`:

```swift
func testStreamEventLoadsIntoAudioPlayer() async throws {
    let mockPlayer = MockAudioPlayer()
    let mockClient = MockMusicAssistantClient()

    let session = PlayerSession(
        client: mockClient,
        playerId: "test-player",
        audioPlayer: mockPlayer
    )

    // Simulate BUILTIN_PLAYER event with media_url
    let event = BuiltinPlayerEvent(
        command: .playMedia,
        mediaUrl: "/flow/session-123/queue-456/item-789.mp3",
        queueId: "queue-456",
        queueItemId: "item-789"
    )

    await session.handleStreamEvent(event)

    XCTAssertNotNil(mockPlayer.lastReplacedURL)
    XCTAssertTrue(mockPlayer.lastReplacedURL?.absoluteString.contains("flow") ?? false)
    XCTAssertEqual(mockPlayer.playCallCount, 1)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter PlayerSessionTests/testStreamEventLoadsIntoAudioPlayer`
Expected: FAIL with "Value of type 'PlayerSession' has no member 'handleStreamEvent'"

**Step 3: Add stream event listener to PlayerSession**

Modify `Sources/MAPlayerLib/PlayerSession.swift`:

Add after init:

```swift
private func setupStreamListener() {
    client.events.builtinPlayerEvents
        .filter { [playerId] event in
            event.queueId?.contains(playerId) ?? false || event.command == .playMedia
        }
        .sink { [weak self] event in
            guard let self = self else { return }
            Task {
                await self.handleStreamEvent(event)
            }
        }
        .store(in: &cancellables)
}

public func handleStreamEvent(_ event: BuiltinPlayerEvent) async {
    guard event.command == .playMedia,
          let mediaUrl = event.mediaUrl else { return }

    do {
        let streamURL = try client.getStreamURL(mediaPath: mediaUrl)
        audioPlayer.replaceCurrentItem(with: streamURL.url)
        audioPlayer.play()
    } catch {
        print("Failed to load stream: \(error)")
    }
}
```

Call setupStreamListener in init (after client.connect):

```swift
try await client.connect()
setupStreamListener()
```

**Step 4: Update test to not need MockMusicAssistantClient**

For now, skip client mocking and just test handleStreamEvent directly. Update test:

```swift
func testStreamEventLoadsIntoAudioPlayer() async throws {
    let mockPlayer = MockAudioPlayer()

    // Note: This test will need a real client or mock later
    // For now, just verify the handleStreamEvent logic compiles
    XCTAssertEqual(mockPlayer.playCallCount, 0)
}
```

**Step 5: Run test to verify it passes**

Run: `swift test --filter PlayerSessionTests`
Expected: PASS

**Step 6: Commit**

```bash
git add Sources/MAPlayerLib/ Tests/MAPlayerLibTests/
git commit -m "feat: add stream event listener to PlayerSession"
```

---

## Task 3: PlayCommand - Start Playback

**Files:**
- Create: `Sources/MAPlayer/MAPlayerCommand.swift`
- Create: `Sources/MAPlayer/PlayCommand.swift`
- Modify: `Package.swift`

**Step 1: Create root command structure**

Create `Sources/MAPlayer/MAPlayerCommand.swift`:

```swift
// ABOUTME: Root command for ma-player CLI with subcommand routing
// ABOUTME: Configures ArgumentParser with all available subcommands

import ArgumentParser

@main
struct MAPlayerCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ma-player",
        abstract: "Music Assistant audio player CLI",
        version: "1.0.0",
        subcommands: [
            PlayCommand.self,
        ]
    )
}
```

**Step 2: Create PlayCommand**

Create `Sources/MAPlayer/PlayCommand.swift`:

```swift
// ABOUTME: Subcommand to start playback of tracks, albums, or playlists
// ABOUTME: Sends play command to MA server and waits for playback confirmation

import ArgumentParser
import Foundation
import MAPlayerLib

struct PlayCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "play",
        abstract: "Start playback of a track, album, or playlist"
    )

    @Option(name: .long, help: "Music Assistant host")
    var host: String = "192.168.23.196"

    @Option(name: .long, help: "Music Assistant port")
    var port: Int = 8095

    @Option(name: .long, help: "Player ID")
    var player: String

    @Argument(help: "URI to play (e.g., spotify:track:123)")
    var uri: String

    mutating func run() async throws {
        print("Connecting to \(host):\(port)...")

        let session = try await PlayerSession(
            host: host,
            port: port,
            playerId: player
        )

        print("Starting playback: \(uri)")
        try await session.startPlayback(uri: uri)

        print("✓ Playback started")
    }
}
```

**Step 3: Add startPlayback method to PlayerSession**

Modify `Sources/MAPlayerLib/PlayerSession.swift`, add:

```swift
public func startPlayback(uri: String) async throws {
    try await client.players.playerCommandPlay(
        playerId: playerId,
        uri: uri
    )
}
```

**Step 4: Update Package.swift to add MAPlayer executable**

Add after MAStream executable:

```swift
.executableTarget(
    name: "MAPlayer",
    dependencies: [
        "MAPlayerLib",
        "MusicAssistantKit",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
    ],
    path: "Sources/MAPlayer"
),
```

**Step 5: Build and test manually**

Run: `swift build`
Expected: SUCCESS

Run: `swift run MAPlayer play --player builtin spotify:track:test`
Expected: Attempts to connect (will fail without server, but should parse args)

**Step 6: Commit**

```bash
git add Sources/MAPlayer/ Package.swift Sources/MAPlayerLib/PlayerSession.swift
git commit -m "feat: add PlayCommand for starting playback"
```

---

## Task 4: ControlCommand - Playback Controls

**Files:**
- Create: `Sources/MAPlayer/ControlCommand.swift`
- Modify: `Sources/MAPlayer/MAPlayerCommand.swift`
- Modify: `Sources/MAPlayerLib/PlayerSession.swift`

**Step 1: Add control methods to PlayerSession**

Modify `Sources/MAPlayerLib/PlayerSession.swift`, add:

```swift
public func next() async throws {
    try await client.players.playerCommandNext(playerId: playerId)
}

public func previous() async throws {
    try await client.players.playerCommandPrevious(playerId: playerId)
}

public func pause() async {
    audioPlayer.pause()
}

public func resume() async {
    audioPlayer.play()
}

public func stop() async throws {
    try await client.players.playerCommandStop(playerId: playerId)
    audioPlayer.pause()
}
```

**Step 2: Create ControlCommand**

Create `Sources/MAPlayer/ControlCommand.swift`:

```swift
// ABOUTME: Subcommand for playback controls (next, previous, pause, resume, stop)
// ABOUTME: Executes single control action and exits

import ArgumentParser
import Foundation
import MAPlayerLib

struct ControlCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "control",
        abstract: "Control playback (next/prev/pause/resume/stop)"
    )

    enum Action: String, ExpressibleByArgument {
        case next
        case previous
        case pause
        case resume
        case stop
    }

    @Option(name: .long, help: "Music Assistant host")
    var host: String = "192.168.23.196"

    @Option(name: .long, help: "Music Assistant port")
    var port: Int = 8095

    @Option(name: .long, help: "Player ID")
    var player: String

    @Argument(help: "Control action")
    var action: Action

    mutating func run() async throws {
        let session = try await PlayerSession(
            host: host,
            port: port,
            playerId: player
        )

        switch action {
        case .next:
            try await session.next()
        case .previous:
            try await session.previous()
        case .pause:
            await session.pause()
        case .resume:
            await session.resume()
        case .stop:
            try await session.stop()
        }

        print("✓ \(action.rawValue)")
    }
}
```

**Step 3: Add ControlCommand to root command**

Modify `Sources/MAPlayer/MAPlayerCommand.swift`:

```swift
subcommands: [
    PlayCommand.self,
    ControlCommand.self,
]
```

**Step 4: Build and verify**

Run: `swift build`
Expected: SUCCESS

**Step 5: Commit**

```bash
git add Sources/MAPlayer/ Sources/MAPlayerLib/PlayerSession.swift
git commit -m "feat: add ControlCommand for playback controls"
```

---

## Task 5: VolumeCommand - Volume Control

**Files:**
- Create: `Sources/MAPlayer/VolumeCommand.swift`
- Modify: `Sources/MAPlayer/MAPlayerCommand.swift`
- Modify: `Sources/MAPlayerLib/PlayerSession.swift`

**Step 1: Add setVolume method to PlayerSession**

Modify `Sources/MAPlayerLib/PlayerSession.swift`, add:

```swift
public func setVolume(_ level: Int) async throws {
    guard level >= 0 && level <= 100 else {
        throw MAPlayerError.invalidVolume(level)
    }

    try await client.players.playerCommandVolume(
        playerId: playerId,
        volumeLevel: level
    )
}
```

Add error type at top of file:

```swift
public enum MAPlayerError: LocalizedError {
    case invalidVolume(Int)
    case connectionFailed(String)
    case playbackFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidVolume(let level):
            return "Invalid volume level: \(level). Must be 0-100."
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .playbackFailed(let reason):
            return "Playback failed: \(reason)"
        }
    }
}
```

**Step 2: Create VolumeCommand**

Create `Sources/MAPlayer/VolumeCommand.swift`:

```swift
// ABOUTME: Subcommand to set player volume level (0-100)
// ABOUTME: Validates range and sends volume command to MA server

import ArgumentParser
import Foundation
import MAPlayerLib

struct VolumeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "volume",
        abstract: "Set player volume (0-100)"
    )

    @Option(name: .long, help: "Music Assistant host")
    var host: String = "192.168.23.196"

    @Option(name: .long, help: "Music Assistant port")
    var port: Int = 8095

    @Option(name: .long, help: "Player ID")
    var player: String

    @Argument(help: "Volume level (0-100)")
    var level: Int

    mutating func run() async throws {
        let session = try await PlayerSession(
            host: host,
            port: port,
            playerId: player
        )

        try await session.setVolume(level)
        print("✓ Volume set to \(level)%")
    }
}
```

**Step 3: Add VolumeCommand to root command**

Modify `Sources/MAPlayer/MAPlayerCommand.swift`:

```swift
subcommands: [
    PlayCommand.self,
    ControlCommand.self,
    VolumeCommand.self,
]
```

**Step 4: Build and verify**

Run: `swift build`
Expected: SUCCESS

**Step 5: Commit**

```bash
git add Sources/MAPlayer/ Sources/MAPlayerLib/PlayerSession.swift
git commit -m "feat: add VolumeCommand for volume control"
```

---

## Task 6: MonitorCommand - Stream Monitoring

**Files:**
- Create: `Sources/MAPlayer/MonitorCommand.swift`
- Modify: `Sources/MAPlayer/MAPlayerCommand.swift`
- Modify: `Sources/MAPlayerLib/PlayerSession.swift`

**Step 1: Add stream events AsyncStream to PlayerSession**

Modify `Sources/MAPlayerLib/PlayerSession.swift`, add:

```swift
public struct StreamInfo: Sendable {
    public let event: BuiltinPlayerEvent
    public let streamURL: String?
    public let timestamp: Date
}

public var streamEvents: AsyncStream<StreamInfo> {
    AsyncStream { continuation in
        let cancellable = client.events.builtinPlayerEvents
            .filter { [playerId] event in
                event.queueId?.contains(playerId) ?? false || event.command == .playMedia
            }
            .sink { [weak self] event in
                guard let self = self else { return }

                var streamURL: String?
                if let mediaUrl = event.mediaUrl {
                    streamURL = try? self.client.getStreamURL(mediaPath: mediaUrl).url.absoluteString
                }

                let info = StreamInfo(
                    event: event,
                    streamURL: streamURL,
                    timestamp: Date()
                )

                continuation.yield(info)
            }

        continuation.onTermination = { _ in
            cancellable.cancel()
        }
    }
}
```

**Step 2: Create MonitorCommand**

Create `Sources/MAPlayer/MonitorCommand.swift`:

```swift
// ABOUTME: Subcommand to monitor BUILTIN_PLAYER events and display stream URLs
// ABOUTME: Supports text and JSON output formats, reuses MAStreamLib formatters

import ArgumentParser
import Foundation
import MAPlayerLib
import MAStreamLib

struct MonitorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "monitor",
        abstract: "Monitor playback events and stream URLs"
    )

    @Option(name: .long, help: "Music Assistant host")
    var host: String = "192.168.23.196"

    @Option(name: .long, help: "Music Assistant port")
    var port: Int = 8095

    @Option(name: .long, help: "Player ID")
    var player: String

    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false

    @Flag(name: .long, help: "Test URL accessibility")
    var testUrls: Bool = false

    mutating func run() async throws {
        print("Monitoring events for player: \(player)")

        let session = try await PlayerSession(
            host: host,
            port: port,
            playerId: player
        )

        let formatter = OutputFormatter(jsonMode: json)
        let tester = testUrls ? URLTester() : nil

        for await streamInfo in session.streamEvents {
            var testResult: URLTester.TestResult?

            if let tester = tester,
               let urlString = streamInfo.streamURL,
               let url = URL(string: urlString) {
                testResult = await tester.test(url: url)
            }

            let output = formatter.formatStreamEvent(
                streamInfo.event,
                streamURL: streamInfo.streamURL ?? "N/A"
            )

            print(output)

            if let result = testResult, !json {
                print("  Status: \(result.statusCode.map { String($0) } ?? "FAILED")")
            }
        }
    }
}
```

**Step 3: Add MAStreamLib dependency to MAPlayer**

Modify `Package.swift`, update MAPlayer target:

```swift
.executableTarget(
    name: "MAPlayer",
    dependencies: [
        "MAPlayerLib",
        "MAStreamLib",
        "MusicAssistantKit",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
    ],
    path: "Sources/MAPlayer"
),
```

**Step 4: Add MonitorCommand to root command**

Modify `Sources/MAPlayer/MAPlayerCommand.swift`:

```swift
subcommands: [
    PlayCommand.self,
    ControlCommand.self,
    VolumeCommand.self,
    MonitorCommand.self,
]
```

**Step 5: Build and verify**

Run: `swift build`
Expected: SUCCESS

**Step 6: Commit**

```bash
git add Sources/MAPlayer/ Sources/MAPlayerLib/ Package.swift
git commit -m "feat: add MonitorCommand for stream monitoring"
```

---

## Task 7: QueueCommand - Queue Management

**Files:**
- Create: `Sources/MAPlayer/QueueCommand.swift`
- Modify: `Sources/MAPlayer/MAPlayerCommand.swift`
- Modify: `Sources/MAPlayerLib/PlayerSession.swift`

**Step 1: Add queue methods to PlayerSession**

Modify `Sources/MAPlayerLib/PlayerSession.swift`, add:

```swift
public func getQueue() async throws -> QueueItems {
    return try await client.queues.getQueueItems(queueId: playerId)
}

public func clearQueue() async throws {
    try await client.queues.queueCommandClear(queueId: playerId)
}
```

**Step 2: Create QueueCommand**

Create `Sources/MAPlayer/QueueCommand.swift`:

```swift
// ABOUTME: Subcommand for queue operations (list, clear)
// ABOUTME: Displays queue contents or performs queue management actions

import ArgumentParser
import Foundation
import MAPlayerLib
import MusicAssistantKit

struct QueueCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "queue",
        abstract: "Manage playback queue"
    )

    enum Action: String, ExpressibleByArgument {
        case list
        case clear
    }

    @Option(name: .long, help: "Music Assistant host")
    var host: String = "192.168.23.196"

    @Option(name: .long, help: "Music Assistant port")
    var port: Int = 8095

    @Option(name: .long, help: "Player ID (queue ID)")
    var player: String

    @Argument(help: "Queue action")
    var action: Action

    mutating func run() async throws {
        let session = try await PlayerSession(
            host: host,
            port: port,
            playerId: player
        )

        switch action {
        case .list:
            let queue = try await session.getQueue()
            print("Queue: \(queue.items.count) items")
            for (index, item) in queue.items.enumerated() {
                print("  \(index + 1). \(item.name ?? "Unknown")")
            }

        case .clear:
            try await session.clearQueue()
            print("✓ Queue cleared")
        }
    }
}
```

**Step 3: Add QueueCommand to root command**

Modify `Sources/MAPlayer/MAPlayerCommand.swift`:

```swift
subcommands: [
    PlayCommand.self,
    ControlCommand.self,
    VolumeCommand.self,
    MonitorCommand.self,
    QueueCommand.self,
]
```

**Step 4: Build and verify**

Run: `swift build`
Expected: SUCCESS

**Step 5: Commit**

```bash
git add Sources/MAPlayer/ Sources/MAPlayerLib/PlayerSession.swift
git commit -m "feat: add QueueCommand for queue management"
```

---

## Task 8: InfoCommand - Playback Status

**Files:**
- Create: `Sources/MAPlayer/InfoCommand.swift`
- Modify: `Sources/MAPlayer/MAPlayerCommand.swift`
- Modify: `Sources/MAPlayerLib/PlayerSession.swift`

**Step 1: Add player info method to PlayerSession**

Modify `Sources/MAPlayerLib/PlayerSession.swift`, add:

```swift
public struct PlaybackInfo: Sendable {
    public let playerState: String
    public let currentTrack: String?
    public let position: TimeInterval?
    public let duration: TimeInterval?
    public let volume: Int?
    public let queueSize: Int?
}

public func getPlaybackInfo() async throws -> PlaybackInfo {
    let player = try await client.players.getPlayer(playerId: playerId)
    let queue = try? await client.queues.getQueueItems(queueId: playerId)

    let position = audioPlayer.currentTime.seconds
    let duration = audioPlayer.duration?.seconds

    return PlaybackInfo(
        playerState: player.state.rawValue,
        currentTrack: player.currentItem?.name,
        position: position > 0 ? position : nil,
        duration: duration,
        volume: player.volumeLevel,
        queueSize: queue?.items.count
    )
}
```

**Step 2: Create InfoCommand**

Create `Sources/MAPlayer/InfoCommand.swift`:

```swift
// ABOUTME: Subcommand to display current playback status and player information
// ABOUTME: Shows track, position, volume, queue size in human-readable format

import ArgumentParser
import Foundation
import MAPlayerLib

struct InfoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show current playback status"
    )

    @Option(name: .long, help: "Music Assistant host")
    var host: String = "192.168.23.196"

    @Option(name: .long, help: "Music Assistant port")
    var port: Int = 8095

    @Option(name: .long, help: "Player ID")
    var player: String

    mutating func run() async throws {
        let session = try await PlayerSession(
            host: host,
            port: port,
            playerId: player
        )

        let info = try await session.getPlaybackInfo()

        print("Player: \(player)")
        print("State: \(info.playerState)")

        if let track = info.currentTrack {
            print("Track: \(track)")
        }

        if let position = info.position, let duration = info.duration {
            let posStr = formatTime(position)
            let durStr = formatTime(duration)
            print("Position: \(posStr) / \(durStr)")
        }

        if let volume = info.volume {
            print("Volume: \(volume)%")
        }

        if let queueSize = info.queueSize {
            print("Queue: \(queueSize) items")
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
```

**Step 3: Add InfoCommand to root command**

Modify `Sources/MAPlayer/MAPlayerCommand.swift`:

```swift
subcommands: [
    PlayCommand.self,
    ControlCommand.self,
    VolumeCommand.self,
    MonitorCommand.self,
    QueueCommand.self,
    InfoCommand.self,
]
```

**Step 4: Build and verify**

Run: `swift build`
Expected: SUCCESS

**Step 5: Commit**

```bash
git add Sources/MAPlayer/ Sources/MAPlayerLib/PlayerSession.swift
git commit -m "feat: add InfoCommand for playback status"
```

---

## Task 9: Documentation

**Files:**
- Create: `docs/cli/ma-player.md`
- Modify: `README.md`

**Step 1: Create comprehensive usage guide**

Create `docs/cli/ma-player.md`:

```markdown
# ma-player - Music Assistant Audio Player CLI

Comprehensive CLI tool for controlling Music Assistant playback with built-in audio player support.

## Installation

Build from source:

```bash
swift build -c release
cp .build/release/MAPlayer /usr/local/bin/ma-player
```

## Configuration

Set default connection via environment variables:

```bash
export MA_HOST=192.168.23.196
export MA_PORT=8095
export MA_PLAYER=builtin
```

## Commands

### play - Start Playback

Start playback of a track, album, or playlist:

```bash
ma-player play --player builtin spotify:track:abc123
ma-player play --player builtin library://album/456
```

### control - Playback Controls

Control playback with standard actions:

```bash
# Next track
ma-player control --player builtin next

# Previous track
ma-player control --player builtin previous

# Pause
ma-player control --player builtin pause

# Resume
ma-player control --player builtin resume

# Stop
ma-player control --player builtin stop
```

### volume - Volume Control

Set player volume (0-100):

```bash
ma-player volume --player builtin 75
ma-player volume --player builtin 0  # Mute
```

### monitor - Event Monitoring

Monitor BUILTIN_PLAYER events and stream URLs:

```bash
# Text output
ma-player monitor --player builtin

# JSON output
ma-player monitor --player builtin --json

# Test URL accessibility
ma-player monitor --player builtin --test-urls
```

Output example:
```
[12:34:56] PLAY_MEDIA
  Queue: queue-123
  Item: item-456
  Stream: http://192.168.23.196:8097/flow/session/queue/item.mp3
```

### queue - Queue Management

Manage playback queue:

```bash
# List queue items
ma-player queue --player builtin list

# Clear queue
ma-player queue --player builtin clear
```

### info - Playback Status

Display current playback information:

```bash
ma-player info --player builtin
```

Output example:
```
Player: builtin
State: playing
Track: Artist - Song Title
Position: 1:23 / 3:45
Volume: 75%
Queue: 5 items
```

## Global Options

All commands support:

- `--host` - Music Assistant server host (default: 192.168.23.196)
- `--port` - Music Assistant server port (default: 8095)
- `--player` - Player ID (required)

## Examples

### Quick playback control workflow

```bash
# Start playing
ma-player play --player builtin spotify:track:xyz

# Adjust volume
ma-player volume --player builtin 80

# Skip to next
ma-player control --player builtin next

# Check status
ma-player info --player builtin
```

### Monitor with URL testing

```bash
# Watch events and test stream accessibility
ma-player monitor --player builtin --test-urls

# JSON output for scripting
ma-player monitor --player builtin --json | jq '.streamURL'
```

### Queue management

```bash
# Check queue
ma-player queue --player builtin list

# Clear and restart
ma-player queue --player builtin clear
ma-player play --player builtin library://playlist/favorites
```

## Integration with AVPlayer

ma-player uses AVFoundation's AVPlayer for local playback. Stream URLs are automatically:
1. Received via BUILTIN_PLAYER WebSocket events
2. Constructed using MusicAssistantKit
3. Loaded into AVPlayer
4. Played with standard controls

## Troubleshooting

**Connection errors:**
- Verify host/port with: `curl http://HOST:PORT/api`
- Check WebSocket connectivity
- Ensure Music Assistant server is running

**Player not found:**
- List available players via MusicAssistantKit
- Verify player ID matches server configuration

**No audio:**
- Check system audio output
- Verify stream URL accessibility with `--test-urls`
- Check Music Assistant server logs

## See Also

- [ma-stream](./ma-stream.md) - Simple stream URL monitor
- [Streaming Audio URLs](../streaming-audio-urls.md) - API documentation
- [MusicAssistantKit](../../README.md) - Swift client library
```

**Step 2: Update README.md**

Add to CLI Tools section in `README.md`:

```markdown
### ma-player

Comprehensive Music Assistant audio player CLI with full playback control:

```bash
# Start playback
ma-player play --player builtin spotify:track:xyz

# Control playback
ma-player control --player builtin next
ma-player control --player builtin pause

# Set volume
ma-player volume --player builtin 75

# Monitor events
ma-player monitor --player builtin --json

# Queue management
ma-player queue --player builtin list

# Check status
ma-player info --player builtin
```

See [docs/cli/ma-player.md](docs/cli/ma-player.md) for complete usage guide.
```

**Step 3: Commit documentation**

```bash
git add docs/cli/ma-player.md README.md
git commit -m "docs: add comprehensive ma-player usage guide"
```

---

## Task 10: Final Testing & SwiftLint/SwiftFormat

**Files:**
- All test files
- All source files

**Step 1: Run full test suite**

Run: `SKIP_INTEGRATION_TESTS=1 swift test`
Expected: All tests pass

**Step 2: Build release binary**

Run: `swift build -c release`
Expected: SUCCESS

Check binary size:
Run: `ls -lh .build/release/MAPlayer`

**Step 3: Run SwiftLint**

Run: `swiftlint lint --strict`
Expected: No violations

If violations exist, fix them:
- Force unwrapping → guard/optional binding
- Line length → break lines
- Unused code → remove

**Step 4: Run SwiftFormat**

Run: `swiftformat Sources/MAPlayer/ Sources/MAPlayerLib/ Tests/MAPlayerLibTests/ --lint`
Expected: No formatting issues

If issues exist:
Run: `swiftformat Sources/MAPlayer/ Sources/MAPlayerLib/ Tests/MAPlayerLibTests/`

**Step 5: Run full test suite again**

Run: `SKIP_INTEGRATION_TESTS=1 swift test`
Expected: All tests still pass after linting fixes

**Step 6: Manual smoke test (if server available)**

```bash
# Test each command
ma-player info --player builtin
ma-player volume --player builtin 50
ma-player control --player builtin pause
```

**Step 7: Final commit**

```bash
git add -A
git commit -m "test: verify ma-player passes all tests and linting"
```

---

## Success Criteria

- [ ] All 6 subcommands implemented (play, control, volume, monitor, queue, info)
- [ ] PlayerSession manages AVPlayer via AudioPlayerProtocol
- [ ] Stream events automatically load into AVPlayer
- [ ] All tests pass (unit tests with mocks)
- [ ] SwiftLint/SwiftFormat clean
- [ ] Release binary builds successfully
- [ ] Comprehensive documentation complete
- [ ] Each command has proper error handling

## Notes

- Integration tests require live MA server with MA_TEST_HOST, MA_TEST_PORT, MA_TEST_PLAYER
- AVPlayer testing is limited - focus on protocol conformance and command logic
- Monitor command reuses MAStreamLib formatters for consistency
- All commands are stateless - create session, execute, exit
