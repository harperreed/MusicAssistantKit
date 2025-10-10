# MusicAssistantKit Changelog

## [Unreleased]

### Fixed
- Fixed ServerInfo decoding to handle additional fields (`base_url`, `onboard_done`) sent by Music Assistant server v2.7.0+
- Fixed Event.data type to use AnyCodable instead of dictionary to handle numeric and other non-dictionary event data
- Removed conflicting keyDecodingStrategy that was preventing proper JSON decoding with explicit CodingKeys
- Fixed race condition in message handler setup by ensuring handler is registered before connection
- Fixed search command to use correct API endpoint (`music/search` instead of `search`) and parameter name (`search` instead of `query`)

### Changed
- Event.data field changed from `[String: AnyCodable]?` to `AnyCodable?` for better flexibility
- EventPublisher now properly converts AnyCodable event data to dictionaries before creating typed events

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
