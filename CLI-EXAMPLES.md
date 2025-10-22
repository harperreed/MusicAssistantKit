# CLI Example Tools

Command-line tools demonstrating MusicAssistantKit usage.

## Building

From the project root:

```bash
swift build
```

Executables will be in `.build/debug/`:
- `ma-control` - Player control (play/pause/stop/seek/group/ungroup)
- `ma-search` - Search library
- `ma-monitor` - Real-time event monitoring
- `ma-player` - Simple streaming player demo
- `ma-player-interactive` - Interactive streaming player with real-time status
- `ma-player-play` - Play a URL through built-in player
- `ma-player-simple` - Basic playMedia test tool
- `ma-player-debug` - Debug tool for built-in player events

## Usage

Control tools accept optional `--host` and `--port` arguments. Default: `192.168.23.196:8095`
Streaming player tools use `MA_HOST` and `MA_PORT` environment variables. Default: `localhost:8095`

### 1. Player Control

```bash
# Use default server (192.168.23.196:8095)
.build/debug/ma-control media_player.kitchen play

# Specify custom server
.build/debug/ma-control --host 192.168.1.100 --port 8095 media_player.kitchen play

# Pause
.build/debug/ma-control media_player.kitchen pause

# Stop
.build/debug/ma-control media_player.kitchen stop

# Seek to position (seconds)
.build/debug/ma-control media_player.kitchen seek 42.5

# Group players
.build/debug/ma-control media_player.kitchen group media_player.bedroom

# Ungroup player
.build/debug/ma-control media_player.kitchen ungroup
```

**Output:**
```
🔌 Connecting to Music Assistant at 192.168.23.196:8095...
✅ Connected!
🎵 Playing media_player.kitchen...
▶️ Playing
👋 Disconnected
```

### 2. Search Library

```bash
# Search for artist/track/album (default server)
.build/debug/ma-search Queen
.build/debug/ma-search "Bohemian Rhapsody"

# Search on custom server
.build/debug/ma-search --host 192.168.1.100 --port 8095 "Beatles"
```

**Output:**
```
🔌 Connecting to Music Assistant at 192.168.23.196:8095...
✅ Connected!
🔍 Searching for 'Queen'...

📊 Search Results:
─────────────────────────────────────────

🎵 Tracks:
  1. Bohemian Rhapsody - Queen [5:55]
  2. We Will Rock You - Queen [2:02]

💿 Albums:
  1. A Night at the Opera - Queen

👤 Artists:
  1. Queen

👋 Disconnected
```

### 3. Real-Time Event Monitor

```bash
# Monitor all players (default server)
.build/debug/ma-monitor

# Monitor specific player
.build/debug/ma-monitor media_player.kitchen

# Monitor on custom server
.build/debug/ma-monitor --host 192.168.1.100 --port 8095
.build/debug/ma-monitor --host 192.168.1.100 --port 8095 media_player.kitchen
```

**Output:**
```
🔌 Connecting to Music Assistant at 192.168.23.196:8095...
✅ Connected!
👀 Monitoring player: media_player.kitchen
Press Ctrl+C to exit

─────────────────────────────────────────

[1:23:45 PM] 🎵 Player Update: media_player.kitchen
  State: ▶️ playing
  Volume: 🔊 65%
  Elapsed: ⏱️  1:23
  Now Playing: 🎶 Bohemian Rhapsody
─────────────────────────────────────────
```

### 4. Streaming Player (Simple Demo)

```bash
# Use default localhost:8095
swift run ma-player

# Use custom server
MA_HOST=music-assistant.local MA_PORT=8095 swift run ma-player
```

**Output:**
```
Music Assistant Streaming Player Demo
======================================
Connecting to localhost:8095...
✓ Connected to Music Assistant

Registering built-in player...
✓ Registered as player: ma_ABCDEF123456

Player is now ready to receive commands from Music Assistant.
You can control it from the Music Assistant web interface.

Press Ctrl+C to stop and unregister.
```

### 5. Interactive Streaming Player

```bash
# Monitor player status in real-time
swift run ma-player-interactive

# With custom server
MA_HOST=192.168.1.100 MA_PORT=8095 swift run ma-player-interactive
```

**Output:** See [INTERACTIVE_PLAYER.md](INTERACTIVE_PLAYER.md) for detailed output examples.

### 6. Play URL Through Built-in Player

```bash
# Play a URL for 30 seconds (default)
swift run ma-player-play "library://track/123"

# Play for custom duration
swift run ma-player-play "https://example.com/song.mp3" --duration 60

# With custom server
MA_HOST=music-assistant.local swift run ma-player-play "library://track/123"
```

**Output:**
```
🎵 Music Assistant URL Player
==================================================
Server: localhost:8095
URL: library://track/123
Duration: 30s

📡 Connecting...
✓ Connected
🎵 Registering player...
✓ Registered as: ma_XYZ123

▶️ Attempting to play URL...
✓ Play command sent successfully

🔊 Streaming from:
   http://localhost:8095/builtin_player/flow/ma_XYZ123.mp3

⏱️ Playing for 30 seconds...
```

## Source Code

### Control Tools
- `Sources/MAControl/main.swift` - Player control implementation
- `Sources/MASearch/main.swift` - Search implementation
- `Sources/MAMonitor/main.swift` - Event monitoring with Combine

### Streaming Player Tools
- `Sources/MAPlayer/main.swift` - Simple streaming player demo
- `Sources/MAPlayerInteractive/main.swift` - Interactive player with real-time status
- `Sources/MAPlayerPlay/main.swift` - URL playback tool
- `Sources/MAPlayerSimple/main.swift` - Basic playMedia test
- `Sources/MAPlayerDebug/main.swift` - Built-in player event debugger

## What They Demonstrate

### Control Tools
- **MAControl**: Basic async/await command execution, error handling, player control
- **MASearch**: Complex JSON result parsing, structured output formatting
- **MAMonitor**: Combine event streams, continuous subscription, data extraction from AnyCodable

### Streaming Player Tools
- **MAPlayer**: StreamingPlayer registration, graceful SIGINT handling
- **MAPlayerInteractive**: Real-time event monitoring, switch expressions, formatted output
- **MAPlayerPlay**: URL streaming, timeout handling, structured error messages
- **MAPlayerSimple**: Basic playMedia command usage
- **MAPlayerDebug**: Raw event debugging, JSON inspection

## Configuration

### Command-Line Arguments (Recommended)

Use `--host` and `--port` flags:

```bash
.build/debug/ma-control --host YOUR_IP --port YOUR_PORT media_player.kitchen play
```

### Default Server

The default server is `192.168.23.196:8095`. To change it, edit the defaults in each `main.swift` file:

```swift
var host = "192.168.23.196"  // Your default server IP
var port = 8095              // Your default server port
```

## Installation (Optional)

Copy executables to your PATH:

```bash
cp .build/debug/ma-* /usr/local/bin/
```

Then use directly:

```bash
ma-control media_player.kitchen play
ma-search "Beatles"
ma-monitor
```
