# Streaming Player Implementation

This document describes the built-in streaming player implementation for MusicAssistantKit.

## Overview

The streaming player allows MusicAssistantKit to register as a player with Music Assistant and stream audio directly to the device running the client. This implements the "built-in player" pattern used by the Music Assistant web frontend.

## Architecture

### Components

1. **BuiltinPlayerState** (`Events/BuiltinPlayerState.swift`)
   - Model representing the current state of the player
   - Sent to server via `builtin_player/update_state` command
   - Contains: powered, playing, paused, position, volume, muted

2. **BuiltinPlayerEvent** (`Events/BuiltinPlayerEvent.swift`)
   - Events received from Music Assistant server
   - Event types: PLAY, PAUSE, STOP, PLAY_MEDIA, SET_VOLUME, MUTE, UNMUTE, POWER_ON, POWER_OFF, TIMEOUT
   - PLAY_MEDIA includes media URL path for streaming

3. **EventPublisher** (`Events/EventPublisher.swift`)
   - Extended to publish built-in player events
   - Routes events from server to StreamingPlayer

4. **MusicAssistantClient** (`Client/MusicAssistantClient.swift`)
   - Added built-in player commands:
     - `registerBuiltinPlayer(playerName:playerId:)` - Register with server
     - `unregisterBuiltinPlayer(playerId:)` - Unregister from server
     - `updateBuiltinPlayerState(playerId:state:)` - Send state updates
   - Exposes `host` and `port` for constructing stream URLs

5. **StreamingPlayer** (`Player/StreamingPlayer.swift`)
   - Main player implementation using AVFoundation
   - Registers with Music Assistant as a built-in player
   - Subscribes to events from server
   - Streams audio from `http://{host}:{port}/builtin_player/flow/{player_id}.mp3`
   - Sends periodic state updates every 30 seconds

## Usage

### Basic Usage

```swift
import MusicAssistantKit

// Create client
let client = MusicAssistantClient(host: "localhost", port: 8095)
try await client.connect()

// Create and register streaming player
let player = StreamingPlayer(client: client, playerName: "My Player")
try await player.register()

// Player is now active and will appear in Music Assistant
// Control it from the Music Assistant web interface

// When done, unregister
try await player.unregister()
await client.disconnect()
```

### Command Line Demo

The `ma-player` executable demonstrates the streaming player:

```bash
# Using default localhost:8095
swift run ma-player

# Using custom host/port
MA_HOST=music-assistant.local MA_PORT=8095 swift run ma-player
```

## How It Works

### Registration Flow

1. Client calls `builtin_player/register` with player name
2. Server creates player with ID like `ma_XXXXXXXXXX`
3. Server registers dynamic route: `/builtin_player/flow/{player_id}.mp3`
4. Client subscribes to `builtin_player` events for this player ID

### Playback Flow

1. User initiates playback in Music Assistant (web UI or automation)
2. Server sends `PLAY_MEDIA` event with `media_url` like `builtin_player/flow/{player_id}.mp3`
3. StreamingPlayer constructs full URL: `http://{host}:{port}/builtin_player/flow/{player_id}.mp3`
4. AVPlayer streams audio from this URL
5. StreamingPlayer sends state updates to server every 30 seconds

### Control Flow

1. User adjusts volume/playback in Music Assistant
2. Server sends event (e.g., `SET_VOLUME`, `PAUSE`, `STOP`)
3. StreamingPlayer handles event and updates AVPlayer
4. StreamingPlayer sends updated state to server

### State Management

The player must send state updates:
- Every 30 seconds (poll interval)
- Whenever state changes (play/pause/stop/volume)
- If no update within 120 seconds, server considers player offline

## Server-Side Implementation

The Music Assistant server implementation can be found at:
- Provider: `music_assistant/providers/builtin_player/provider.py`
- Player: `music_assistant/providers/builtin_player/player.py`

Key server behaviors:
- Streams audio in real-time from player queue
- Supports MP3 and FLAC formats
- Handles iOS/iPadOS probe requests
- Applies audio filters and transcoding via FFmpeg

## Platform Support

- **macOS**: ✅ 12.0+
- **iOS**: ✅ 15.0+
- **Linux**: ❌ (AVFoundation not available)
- **Windows**: ❌ (AVFoundation not available)

## Future Enhancements

Potential improvements:
- [ ] Add support for multiple simultaneous players
- [ ] Implement seeking/position control
- [ ] Add audio format selection (MP3 vs FLAC)
- [ ] Support for Linux/Windows using different audio backends
- [ ] Better error handling and reconnection logic
- [ ] Audio visualization/metadata display
- [ ] Background audio support for iOS
- [ ] AirPlay/casting integration

## References

- [Music Assistant Frontend API](https://github.com/music-assistant/frontend/blob/main/src/plugins/api/index.ts)
- [Music Assistant Server Builtin Player](https://github.com/music-assistant/server/tree/dev/music_assistant/providers/builtin_player)
- [Music Assistant Documentation](https://music-assistant.io/player-support/builtin/)
