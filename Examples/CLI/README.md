# MusicAssistantKit CLI Examples

Simple command-line tools demonstrating how to use the MusicAssistantKit library.

## Prerequisites

- Swift 5.7+
- Music Assistant server running at `192.168.23.196:8095`
- MusicAssistantKit built (`swift build` from project root)

## Running the Examples

From the project root directory:

```bash
cd Examples/CLI
```

## 1. Player Control (`ma-control.swift`)

Control playback on Music Assistant players.

### Usage

```bash
swift ma-control.swift <player-id> <play|pause|stop>
```

### Examples

```bash
# Play on kitchen speaker
swift ma-control.swift media_player.kitchen play

# Pause bedroom player
swift ma-control.swift media_player.bedroom pause

# Stop all playback
swift ma-control.swift media_player.living_room stop
```

### Output

```
🔌 Connecting to Music Assistant at 192.168.23.196:8095...
✅ Connected!
🎵 Sending play command to media_player.kitchen...
▶️  Playing
👋 Disconnected
```

## 2. Search (`ma-search.swift`)

Search your Music Assistant library for tracks, albums, artists, and playlists.

### Usage

```bash
swift ma-search.swift <query>
```

### Examples

```bash
# Search for Queen
swift ma-search.swift Queen

# Search for a song
swift ma-search.swift "Bohemian Rhapsody"

# Search for an album
swift ma-search.swift "Abbey Road"
```

### Output

```
🔌 Connecting to Music Assistant at 192.168.23.196:8095...
✅ Connected!
🔍 Searching for 'Queen'...

📊 Search Results:
─────────────────────────────────────────

🎵 Tracks:
  1. Bohemian Rhapsody - Queen [5:55]
  2. We Will Rock You - Queen [2:02]
  3. We Are The Champions - Queen [2:59]

💿 Albums:
  1. A Night at the Opera - Queen
  2. News of the World - Queen

👤 Artists:
  1. Queen

👋 Disconnected
```

## 3. Event Monitor (`ma-monitor.swift`)

Monitor Music Assistant player and queue events in real-time using Combine.

### Usage

```bash
# Monitor all players
swift ma-monitor.swift

# Monitor specific player
swift ma-monitor.swift <player-id>
```

### Examples

```bash
# Watch all player events
swift ma-monitor.swift

# Watch only kitchen speaker
swift ma-monitor.swift media_player.kitchen
```

### Output

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

[1:24:10 PM] 📋 Queue Update: media_player.kitchen
  Items in queue: 12
  Shuffle: 🔀 On
  Repeat: 🔁 all
─────────────────────────────────────────
```

## How They Work

### Player Control
- Uses async/await for clean command execution
- Demonstrates basic client lifecycle (connect → command → disconnect)
- Shows proper error handling

### Search
- Demonstrates command with arguments
- Parses and displays structured JSON results
- Shows type casting and safe unwrapping

### Event Monitor
- Demonstrates Combine event streams
- Shows continuous event subscription
- Illustrates filtering events by player ID
- Uses async task to keep connection alive

## Tips

1. **Make scripts executable:**
   ```bash
   chmod +x *.swift
   ./ma-control.swift media_player.kitchen play
   ```

2. **Change server address:**
   Edit the `host` and `port` constants at the top of each file.

3. **Build MusicAssistantKit first:**
   ```bash
   cd ../..  # Back to project root
   swift build
   ```

4. **Find your player IDs:**
   Check your Music Assistant web UI or use the API to list players.

## Next Steps

Use these examples as templates for:
- Building CLI tools for your workflow
- Testing the library during development
- Learning the MusicAssistantKit API
- Creating automation scripts

## Troubleshooting

**"MusicAssistantKit not found"**
- Make sure you're running from the project root or Examples/CLI directory
- Run `swift build` in the project root first

**Connection errors**
- Verify Music Assistant is running at 192.168.23.196:8095
- Check network connectivity
- Update host/port in the script if different

**No events in monitor**
- Trigger events by using the Music Assistant app
- Check that you're monitoring the correct player ID
- Ensure the player is active and receiving commands
