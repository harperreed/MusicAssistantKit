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
