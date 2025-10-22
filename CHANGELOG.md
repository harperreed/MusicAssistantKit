# MusicAssistantKit Changelog

## [Unreleased]

## [0.2.0] - 2025-10-22

### Added
- **Streaming Player Support** - Built-in player implementation using AVFoundation for direct audio streaming
  - `StreamingPlayer` actor for registering and managing built-in players
  - `BuiltinPlayerState` model for state updates (powered, playing, paused, position, volume, muted)
  - `BuiltinPlayerEvent` model for server commands (PLAY, PAUSE, STOP, PLAY_MEDIA, SET_VOLUME, MUTE, UNMUTE, POWER_ON, POWER_OFF, TIMEOUT)
  - Built-in player commands in `MusicAssistantClient`:
    - `registerBuiltinPlayer(playerName:playerId:)` - Register with server
    - `unregisterBuiltinPlayer(playerId:)` - Unregister from server
    - `updateBuiltinPlayerState(playerId:state:)` - Send state updates
  - `builtinPlayerEvents` publisher in EventPublisher for built-in player events
  - Automatic state updates every 30 seconds
  - Graceful SIGINT handling for player shutdown
  - Audio session configuration for iOS/macOS
  - Time observer for position tracking

- **Player Control Commands** - Additional player control functionality
  - `next(playerId:)` - Skip to next track
  - `previous(playerId:)` - Skip to previous track
  - `setVolume(playerId:volume:)` - Set player volume
  - `seek(playerId:position:)` - Seek to position in current track
  - `group(playerId:targetPlayer:)` - Group players together
  - `ungroup(playerId:)` - Ungroup player

- **CLI Streaming Player Tools** - Command-line demonstrations
  - `ma-player` - Simple streaming player demo
  - `ma-player-interactive` - Interactive player with real-time status updates
  - `ma-player-play` - Play a URL through built-in player with timeout handling
  - `ma-player-simple` - Basic playMedia test tool
  - `ma-player-debug` - Debug tool for built-in player events

- **Documentation**
  - `STREAMING.md` - Comprehensive streaming player documentation
  - `INTERACTIVE_PLAYER.md` - Interactive player guide
  - `BUILTIN_PLAYER_FAQ.md` - Frequently asked questions
  - Updated `README.md` with streaming player examples
  - Updated `CLI-EXAMPLES.md` with all new tools

### Fixed
- Fixed ServerInfo decoding to handle additional fields (`base_url`, `onboard_done`) sent by Music Assistant server v2.7.0+
- Fixed Event.data type to use AnyCodable instead of dictionary to handle numeric and other non-dictionary event data
- Removed conflicting keyDecodingStrategy that was preventing proper JSON decoding with explicit CodingKeys
- Fixed race condition in message handler setup by ensuring handler is registered before connection
- Fixed search command to use correct API endpoint (`music/search` instead of `search`) and parameter name (`search` instead of `query`)
- Fixed timeout task leaks in MusicAssistantClient by tracking and canceling timeout tasks
- Fixed actor isolation issues in sendCommand by using proper helper methods
- Fixed continuation leak risks by removing unnecessary weak self captures
- Fixed SIGINT handling in MAPlayer to use DispatchSource for graceful shutdown
- Fixed SwiftFormat compliance issues (double spaces, brace placement)

### Changed
- Event.data field changed from `[String: AnyCodable]?` to `AnyCodable?` for better flexibility
- EventPublisher now properly converts AnyCodable event data to dictionaries before creating typed events
- Modernized MAPlayerInteractive to use switch expressions with single let bindings
- MusicAssistantClient now exposes `host` and `port` properties for stream URL construction

## [0.1.0] - 2025-10-10

### Added
- Initial release of MusicAssistantKit
- WebSocket-based Music Assistant client with actor-based architecture
- Hybrid API: async/await for commands, Combine for events
- Automatic reconnection with exponential backoff
- Player control commands (play, pause, stop)
- Search functionality across Music Assistant library
- Queue management commands
- Real-time event monitoring via Combine publishers
- Three CLI example tools: ma-control, ma-search, ma-monitor
