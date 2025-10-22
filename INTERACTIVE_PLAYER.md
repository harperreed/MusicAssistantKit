# Interactive Streaming Player

A minimal mpv-style CLI app for testing Music Assistant streaming functionality in real-time.

## What It Does

The interactive player:
- Registers as a built-in player with your Music Assistant server
- Displays real-time status updates as you control playback
- Shows event notifications with timestamps and emoji indicators
- Provides a clean, minimal interface for testing streaming

## Usage

### Quick Start

```bash
# Connect to localhost:8095 (default)
swift run ma-player-interactive

# Connect to custom host/port
MA_HOST=music-assistant.local MA_PORT=8095 swift run ma-player-interactive
```

### What You'll See

```
╔════════════════════════════════════════════════╗
║   Music Assistant Interactive Player          ║
║   Minimal mpv-style streaming test app        ║
╚════════════════════════════════════════════════╝

📡 Connecting to localhost:8095...
✓ Connected to Music Assistant

🎵 Registering player: MusicAssistantKit Interactive [12345]
✓ Registered as player ID: ma_ABCDEF123456

╔════════════════════════════════════════════════╗
║              READY TO STREAM                   ║
╠════════════════════════════════════════════════╣
║                                                ║
║  Control this player from Music Assistant      ║
║  web interface at http://localhost:8095/       ║
║                                                ║
║  The player will show up as:                   ║
║  "MusicAssistantKit Interactive [12345]"       ║
║                                                ║
╠════════════════════════════════════════════════╣
║  Status will be displayed here in real-time    ║
╚════════════════════════════════════════════════╝

💡 TIP: Queue some music in Music Assistant and play it!
💡 You should see status updates appear here as you control playback

Press Ctrl+C to stop and unregister

─────────────────────────────────────────────────

[14:23:45] 🎶 STREAMING: builtin_player/flow/ma_ABCDEF123456.mp3
[14:23:50] ▶️  PLAYING
[14:24:10] 🔊 VOLUME: 75%
[14:24:20] ⏸️  PAUSED
[14:24:25] ▶️  PLAYING
[14:25:00] ⏹️  STOPPED
```

## Event Indicators

The player displays real-time events with these indicators:

- 🎶 **STREAMING** - Audio stream URL received
- ▶️  **PLAYING** - Playback started
- ⏸️  **PAUSED** - Playback paused
- ⏹️  **STOPPED** - Playback stopped
- 🔊 **VOLUME** - Volume changed (shows percentage)
- 🔇 **MUTED** - Audio muted
- 🔊 **UNMUTED** - Audio unmuted
- ⚡ **POWER ON** - Player powered on
- 💤 **POWER OFF** - Player powered off
- 📡 **Other events** - Any other built-in player events

## How to Test

1. **Start the player:**
   ```bash
   swift run ma-player-interactive
   ```

2. **Open Music Assistant web interface:**
   - Navigate to `http://localhost:8095/` (or your custom host:port)
   - You should see the player listed in the players section

3. **Queue some music:**
   - Search for a song/album/playlist
   - Add it to the queue
   - Select your "MusicAssistantKit Interactive" player

4. **Control playback:**
   - Press play/pause
   - Adjust volume
   - Skip tracks
   - Watch the CLI update in real-time!

5. **Exit gracefully:**
   - Press `Ctrl+C` to stop
   - Player will unregister automatically

## Differences from `ma-player`

| Feature | `ma-player` | `ma-player-interactive` |
|---------|-------------|-------------------------|
| Purpose | Simple demo | Testing & debugging |
| Output | Minimal | Real-time status updates |
| Events | Hidden | Displayed with timestamps |
| Style | Fire & forget | Interactive monitoring |
| Best for | Proof of concept | Development & testing |

## Troubleshooting

**Player doesn't appear in Music Assistant:**
- Check that Music Assistant server is running
- Verify host:port are correct
- Look for connection errors in the output

**No events showing:**
- Make sure you've selected the player in Music Assistant
- Try queuing and playing some music
- Check that the player ID matches what's registered

**Audio not playing:**
- This is normal! The CLI shows status but the actual StreamingPlayer handles audio
- Audio should play through your system's default audio output
- Check system volume isn't muted

**Ctrl+C doesn't work:**
- Try `Ctrl+\` (SIGQUIT) instead
- If still stuck, use `kill` from another terminal

## Platform Support

- ✅ macOS 12.0+
- ✅ iOS 15.0+ (though CLI apps on iOS are unusual)
- ❌ Linux (AVFoundation not available)
- ❌ Windows (AVFoundation not available)

## See Also

- `STREAMING.md` - Full streaming player documentation
- `ma-player` - Simple non-interactive demo
- `ma-monitor` - General Music Assistant event monitor
