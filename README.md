# MusicAssistantKit

A robust, lightweight Swift library for controlling [Music Assistant](https://music-assistant.io) via WebSocket API.

## Features

- **Actor-based architecture** - Thread-safe by design with Swift Concurrency
- **Hybrid API** - async/await for commands, Combine for event streams
- **Automatic reconnection** - Exponential backoff (1s to 60s)
- **Core functionality** - Play control, search, queue management
- **Streaming player** - Built-in player using AVFoundation for direct audio streaming
- **TDD approach** - Comprehensive test coverage against real server

## Requirements

- iOS 15+ / macOS 12+
- Swift 5.7+
- Music Assistant server running on your network

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/MusicAssistantKit.git", from: "1.0.0")
]
```

## Quick Start

```swift
import MusicAssistantKit

// Create client
let client = MusicAssistantClient(host: "192.168.23.196", port: 8095)

// Connect
try await client.connect()

// Send commands (async/await)
try await client.play(playerId: "media_player.kitchen")
let results = try await client.search(query: "Beatles")

// Subscribe to events (Combine)
client.events.playerUpdates
    .sink { event in
        print("Player \(event.playerId) updated")
    }
    .store(in: &cancellables)

// Disconnect
await client.disconnect()
```

## API Overview

### Player Control

```swift
try await client.play(playerId: "media_player.kitchen")
try await client.pause(playerId: "media_player.kitchen")
try await client.stop(playerId: "media_player.kitchen")
```

### Search

```swift
let results = try await client.search(query: "Beatles", limit: 25)
```

### Queue Management

```swift
// Play media
try await client.playMedia(
    queueId: "media_player.kitchen",
    uri: "library://track/12345",
    option: "play"
)

// Get queue items
let items = try await client.getQueueItems(queueId: "media_player.kitchen")

// Clear queue
try await client.clearQueue(queueId: "media_player.kitchen")

// Shuffle
try await client.shuffle(queueId: "media_player.kitchen", enabled: true)

// Repeat
try await client.setRepeat(queueId: "media_player.kitchen", mode: "all")
```

### Events

```swift
// Player updates
client.events.playerUpdates
    .sink { event in
        print("Player: \(event.playerId), Data: \(event.data)")
    }
    .store(in: &cancellables)

// Queue updates
client.events.queueUpdates
    .sink { event in
        print("Queue: \(event.queueId), Data: \(event.data)")
    }
    .store(in: &cancellables)
```

### Streaming Player

Create a built-in player that streams audio directly to your device:

```swift
import MusicAssistantKit

// Create client and connect
let client = MusicAssistantClient(host: "localhost", port: 8095)
try await client.connect()

// Create and register streaming player
let player = StreamingPlayer(client: client, playerName: "My Streaming Player")
try await player.register()

// Player now appears in Music Assistant and can be controlled from the web interface
// Audio will stream from http://host:port/builtin_player/flow/{player_id}.mp3

// When done, unregister
try await player.unregister()
await client.disconnect()
```

The streaming player:
- Registers as a built-in player with Music Assistant
- Streams audio using AVFoundation (macOS/iOS only)
- Sends state updates every 30 seconds
- Responds to play/pause/stop/volume commands from the server
- Automatically handles audio session configuration

See [STREAMING.md](STREAMING.md) for detailed documentation.

**CLI Tools:**
```bash
# Simple player demo
MA_HOST=localhost MA_PORT=8095 swift run ma-player

# Interactive player with real-time status
MA_HOST=localhost MA_PORT=8095 swift run ma-player-interactive

# Play a URL directly
MA_HOST=localhost swift run ma-player-play "library://track/123"
```

## Error Handling

```swift
do {
    try await client.play(playerId: "kitchen")
} catch MusicAssistantError.notConnected {
    print("Not connected to server")
} catch MusicAssistantError.commandTimeout(let messageId) {
    print("Command \(messageId) timed out")
} catch MusicAssistantError.serverError(let code, let message, _) {
    print("Server error \(code ?? 0): \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Testing

Tests require a Music Assistant server running at `192.168.23.196:8095` (configurable in test files).

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter ClientCommandTests

# Run integration tests only
swift test --filter Integration
```

## Architecture

- **MusicAssistantClient** - Main actor providing public API
- **WebSocketConnection** - Actor managing WebSocket lifecycle and reconnection
- **EventPublisher** - Combine-based event broadcasting
- **Message Models** - Codable types matching AsyncAPI spec

## License

Apache 2.0

## Contributing

PRs welcome! Please include tests for new features.

## Acknowledgments

Built for [Music Assistant](https://music-assistant.io) - the open-source music server.
