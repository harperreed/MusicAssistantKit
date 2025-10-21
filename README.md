# MusicAssistantKit

A robust, lightweight Swift library for controlling [Music Assistant](https://music-assistant.io) via WebSocket API.

## Features

- **Actor-based architecture** - Thread-safe by design with Swift Concurrency
- **Hybrid API** - async/await for commands, Combine for event streams
- **Automatic reconnection** - Exponential backoff (1s to 60s)
- **Core functionality** - Play control, search, queue management
- **Resonate Protocol** - Direct streaming support for synchronized multi-room audio
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

### Resonate Protocol Streaming (Experimental)

> **⚠️ Experimental Feature**: Resonate protocol support is experimental and under active development. The API endpoints and data structures shown below are speculative and based on protocol documentation. **You should verify these endpoints against your actual Music Assistant server implementation.** Expect possible changes or incompatibilities as the Resonate protocol evolves.

MusicAssistantKit supports the Resonate protocol for direct streaming with synchronized multi-room audio playback.

```swift
// Check if server supports Resonate protocol
let supportsResonate = await client.supportsResonateProtocol()

if supportsResonate {
    // Get streaming information for a queue (synchronized playback)
    if let streamInfo = try await client.getResonateStream(queueId: "media_player.kitchen") {
        print("Stream URL: \(streamInfo.url)")
        print("Format: \(streamInfo.format.codec) @ \(streamInfo.format.sampleRate ?? 0)Hz")
        print("Lossless: \(streamInfo.format.isLossless)")

        // Use streamInfo.url with your audio player (e.g., AVPlayer)
        // The Resonate protocol provides sub-millisecond synchronization
        // for perfect multi-room audio playback
    }
}

// Get streaming URL for a specific media item
if let streamInfo = try await client.getStreamURL(
    mediaItemId: "track_12345",
    preferredProtocol: .resonate
) {
    print("Direct stream: \(streamInfo.url)")
}

// Get server capabilities and base URL
if let serverInfo = await client.getServerInfo() {
    print("Server version: \(serverInfo.serverVersion)")
    print("Base URL: \(serverInfo.baseUrl ?? "N/A")")
    print("Capabilities: \(serverInfo.capabilities ?? [])")
}
```

#### Streaming Protocols

MusicAssistantKit supports multiple streaming protocols:

- **`.resonate`** - Resonate protocol for synchronized multi-room HiFi audio (WebSocket-based)
- **`.http`** - Standard HTTP streaming
- **`.https`** - HTTPS streaming
- **`.file`** - Direct file access

#### Audio Formats

The `AudioFormat` struct provides comprehensive format information:

```swift
let format = streamInfo.format
print("Codec: \(format.codec)")           // e.g., "flac", "mp3", "aac"
print("Sample Rate: \(format.sampleRate ?? 0)Hz")  // e.g., 44100, 48000, 96000
print("Bit Depth: \(format.bitDepth ?? 0)")        // e.g., 16, 24
print("Bitrate: \(format.bitrate ?? 0)kbps")       // for lossy formats
print("Lossless: \(format.isLossless)")    // true for FLAC, ALAC, WAV
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
