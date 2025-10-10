# CLI Example Tools

Three command-line tools demonstrating MusicAssistantKit usage.

## Building

From the project root:

```bash
swift build
```

Executables will be in `.build/debug/`:
- `ma-control` - Player control (play/pause/stop)
- `ma-search` - Search library
- `ma-monitor` - Real-time event monitoring

## Usage

All tools accept optional `--host` and `--port` arguments. Default: `192.168.23.196:8095`

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
```

**Output:**
```
🔌 Connecting to Music Assistant at 192.168.23.196:8095...
✅ Connected!
🎵 Sending play command to media_player.kitchen...
▶️  Playing
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

## Source Code

- `Sources/MAControl/main.swift` - Player control implementation
- `Sources/MASearch/main.swift` - Search implementation
- `Sources/MAMonitor/main.swift` - Event monitoring with Combine

## What They Demonstrate

- **MAControl**: Basic async/await command execution, error handling
- **MASearch**: Complex JSON result parsing, structured output formatting
- **MAMonitor**: Combine event streams, continuous subscription, data extraction from AnyCodable

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
