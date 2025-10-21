# Built-in Player FAQ

## Why doesn't my player show up in the Music Assistant UI?

**Short answer:** It does! But it's hidden by default.

Built-in players are configured with `"hide_player_in_ui": ["always"]` by Music Assistant. This is intentional - they're designed to be controlled programmatically, not through the web UI.

### Proof it's working:

Run the debug tool to see your player in the full player list:

```bash
MA_HOST=192.168.23.196 MA_PORT=8095 swift run ma-player-debug
```

You'll see output like:

```
✓ Our player found in list:
   player_id: ma_9z7dkyrhq5
   display_name: Test Debug Player
   provider: builtin_player
   hide_player_in_ui: ["always"]  ← This is why it's hidden
   available: true
   powered: false
```

## How do I actually use the player then?

### Option 1: Programmatic Control (Recommended)

Control the player through the Music Assistant API:

```swift
// Queue and play media to your built-in player
try await client.playMedia(
    playerId: "ma_YOUR_PLAYER_ID",
    media: "library://track/123"
)
```

### Option 2: Use as a Streaming Endpoint

The built-in player acts as a streaming endpoint. When Music Assistant sends a `PLAY_MEDIA` event with a stream URL, the player will:

1. Receive the event with media URL
2. Construct full streaming URL
3. Play audio through AVPlayer
4. Send state updates back to server

### Option 3: Modify Server Config (Not Recommended)

You could potentially modify the Music Assistant server code to change the `hide_player_in_ui` setting, but this isn't recommended as it goes against the intended design.

## What's the point if I can't see it in the UI?

Built-in players are designed for:

1. **Programmatic Playback**: Control audio from code/scripts
2. **Testing**: Verify streaming functionality works
3. **Automation**: Create custom player logic
4. **Development**: Build custom Music Assistant clients

They're not meant to replace regular players in the UI - they're meant to BE the client.

## How do I know if it's actually working?

### Using the Interactive Player:

```bash
MA_HOST=192.168.23.196 MA_PORT=8095 swift run ma-player-interactive
```

When you trigger playback (via API or automation), you'll see real-time events:

```
[14:23:45] 🎶 STREAMING: builtin_player/flow/ma_XXXXX.mp3
[14:23:50] ▶️  PLAYING
[14:24:10] 🔊 VOLUME: 75%
```

### Using the Debug Tool:

```bash
MA_HOST=192.168.23.196 MA_PORT=8095 swift run ma-player-debug
```

Shows full registration details and confirms the player is in the server's player list.

## Can I make it show up in the UI anyway?

The `hide_player_in_ui` setting is controlled server-side when the player registers. Currently, there's no client-side way to override this.

However, you could:

1. **Feature Request**: Ask the Music Assistant team to add a server setting for built-in player visibility
2. **Fork the Server**: Modify the built-in player provider code
3. **Use a Different Player Type**: If you need UI visibility, implement a different player protocol

## What's the difference from web frontend's player?

The Music Assistant web frontend uses built-in players the same way - they're hidden from the UI but actively stream audio. The web UI itself IS a built-in player client!

When you play music in the web interface, it:
1. Registers a built-in player
2. Receives streaming URLs
3. Plays audio in the browser
4. Sends state updates

Your Swift implementation does exactly the same thing, just in Swift instead of TypeScript.

## Related

- See `INTERACTIVE_PLAYER.md` for testing with real-time event display
- See `STREAMING.md` for full architecture documentation
- See Music Assistant docs: https://music-assistant.io/player-support/builtin/
