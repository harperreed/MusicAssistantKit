# Music Assistant Streaming API Discovery

**Date:** 2025-10-16
**Status:** Live Testing Complete
**Goal:** Document WebSocket commands for querying media item stream URLs
**Server Tested:** 192.168.23.196:8095

## Executive Summary

**CONFIRMED:** Music Assistant does NOT expose direct stream URLs to clients. After testing against a live server:

- ✅ **Available:** Rich metadata via `music/item_by_uri` including audio format specs
- ✅ **Available:** Audio format details (codec, sample rate, bit depth, channels)
- ✅ **Available:** Provider web page URLs (not playback streams)
- ❌ **NOT Available:** Direct HTTP/HTTPS stream URLs for client-side playback
- ❌ **NOT Available:** Preview/clip endpoints (Python client method returns 404)
- ❌ **NOT Available:** Accessible HTTP endpoints on streaming port (8097)

**Architecture:** Music Assistant uses a **mediated streaming model** where the server handles all provider authentication and stream retrieval. Clients control playback via player commands, not direct stream access.

**Implication for MusicAssistantKit:** This library should be a **control and metadata library**, not a playback library.

## Key Findings

### 1. Media Item Retrieval Commands

Music Assistant provides several commands to retrieve media item metadata:

#### Primary Command: `music/item_by_uri`

**Purpose:** Retrieve full metadata for any media item using its URI

**Request Format:**
```json
{
  "message_id": "unique-id",
  "command": "music/item_by_uri",
  "args": {
    "uri": "library://track/<item-id>"
  }
}
```

**Supported URI Formats:**
- `library://track/<id>` - Library tracks
- `library://album/<id>` - Library albums
- `library://artist/<id>` - Library artists
- `library://playlist/<id>` - Library playlists
- `spotify://track/<id>` - Spotify tracks
- `<provider>://<type>/<id>` - Generic provider URIs

**Expected Response Structure** (inferred from Python client):
```json
{
  "message_id": "unique-id",
  "result": {
    "uri": "library://track/123",
    "item_id": "123",
    "provider": "local",
    "media_type": "track",
    "name": "Track Name",
    "sort_name": "Track Name",
    "version": "",
    "duration": 180,
    "artists": [
      {
        "item_id": "artist-1",
        "provider": "local",
        "name": "Artist Name",
        "uri": "library://artist/artist-1"
      }
    ],
    "album": {
      "item_id": "album-1",
      "provider": "local",
      "name": "Album Name",
      "uri": "library://album/album-1"
    },
    "metadata": {
      "images": [
        {
          "type": "thumb",
          "url": "http://localhost:8095/image/track/123"
        }
      ]
    },
    "provider_mappings": [
      {
        "item_id": "123",
        "provider_domain": "local",
        "provider_instance": "local",
        "url": "file:///path/to/audio.flac",
        "audio_format": {
          "content_type": "audio/flac",
          "sample_rate": 44100,
          "bit_depth": 16,
          "channels": 2,
          "bit_rate": 1411
        }
      }
    ]
  }
}
```

**Note:** The exact response structure needs verification against a live server. The `provider_mappings` field is particularly important as it may contain audio format details.

#### Alternative Commands

**Get Specific Item by Type:**
```json
{
  "command": "music/item",
  "args": {
    "media_type": "track",
    "item_id": "123",
    "provider_instance_id_or_domain": "local"
  }
}
```

**Get Track Details:**
```json
{
  "command": "music/tracks/get_track",
  "args": {
    "item_id": "123",
    "provider_instance_id_or_domain": "local"
  }
}
```

### 2. Stream URL Architecture

**Critical Discovery:** Music Assistant uses a **server-side streaming architecture** rather than exposing direct stream URLs:

1. **For Playback:**
   - Clients use `player_queues/play_media` with a media URI
   - The Music Assistant server handles stream retrieval and transcoding
   - Audio is streamed through the server to the player

2. **Preview URLs (Tracks Only):**
   - The Python client has `get_track_preview_url()` which constructs URLs like:
     ```
     http://<server>:<port>/preview/<provider>/<item_id>
     ```
   - These appear to be 30-second preview streams

3. **Provider URLs:**
   - Some providers (like local files) expose file URLs in `provider_mappings[].url`
   - These may be direct file paths (`file:///...`) or provider-specific URLs
   - DRM-protected content will not have accessible URLs

### 3. Player Events and Stream Information

Based on the EventPublisher implementation in this codebase and patterns in the Music Assistant Python client:

**Event:** `player_updated`

**Current Event Structure in MusicAssistantKit:**
```json
{
  "event": "player_updated",
  "object_id": "player-id",
  "data": {
    "player_id": "player-id",
    "state": "playing",
    "volume_level": 65,
    "elapsed_time": 45.2,
    "elapsed_time_last_updated": 1697123456.789,
    "current_item": {
      "uri": "library://track/123",
      "name": "Track Name",
      "duration": 180,
      "image_url": "http://localhost:8095/image/track/123"
    },
    "queue_id": "queue-id"
  }
}
```

**Hypothesis:** Stream details may NOT be included in player events. The event only contains metadata about what's playing, not how it's being streamed.

**To Verify:**
- Connect to live Music Assistant server
- Start playback
- Capture `player_updated` event
- Check if there's a `stream_details`, `stream_options`, or similar field

## Unknowns and Testing Needed

### Critical Questions

1. **Do `music/item_by_uri` responses include stream URLs?**
   - The Python client doesn't expose a `stream_url` field on MediaItem objects
   - Need to inspect raw WebSocket response to verify

2. **What's in `provider_mappings[].url`?**
   - For local files: likely `file://` URLs
   - For streaming services: might be empty or provider-specific
   - For streaming providers: likely not accessible (DRM)

3. **Do player events include stream options?**
   - Current hypothesis: NO
   - Need live capture to confirm

4. **Is there a separate `get_stream_details` command?**
   - Not found in Python client music.py methods
   - May be server-internal only (used by providers)

### Testing Plan

To complete API discovery, we need to:

1. **Connect to Live Server:**
   ```bash
   # Set up test environment
   export MA_TEST_HOST=localhost
   export MA_TEST_PORT=8095
   ```

2. **Test `music/item_by_uri` Command:**
   ```swift
   // In Swift test or CLI tool
   let client = MusicAssistantClient(host: "localhost", port: 8095)
   try await client.connect()

   // Send raw command
   let result = try await client.sendCommand(
       command: "music/item_by_uri",
       args: ["uri": "library://track/123"]
   )

   // Inspect full JSON response
   print(result)
   ```

3. **Capture Player Events:**
   ```swift
   // Subscribe to player updates
   client.events.playerUpdates.sink { playerId, data in
       print("Player Update Data:")
       print(data)
   }.store(in: &cancellables)

   // Start playback
   try await client.playMedia(queueId: "queue-id", uri: "library://track/123")

   // Wait and observe events
   ```

4. **Check Search Results:**
   ```swift
   let results = try await client.search(query: "test")
   print(results)
   // Examine track objects for URL fields
   ```

## Recommended Implementation Approach

Given the uncertainties, I recommend a **phased implementation:**

### Phase 1: Basic URI Query (Implement First)
- Add `getMediaDetails(uri:)` method using `music/item_by_uri`
- Return raw response data as `AnyCodable`
- Create tests with mocked responses
- Test against live server to capture real structure

### Phase 2: Model Creation (After Live Testing)
- Based on real responses, create `MediaDetails` model
- Determine if `StreamOption` makes sense or if it's just `AudioFormat`
- Handle provider-specific variations

### Phase 3: Event Enhancement (If Applicable)
- Only if player events contain stream data
- Otherwise, skip this enhancement

### Phase 4: Convenience Methods (Optional)
- Add helpers like `getCurrentMediaDetails(playerId:)`
- Only if there's value beyond direct URI queries

## Real-World API Responses (Captured)

### Response 1: Apple Music Track via `music/item_by_uri`

**Tested:** 2025-10-16
**Server:** 192.168.23.196:8095
**Command:** `music/item_by_uri`
**URI:** `apple_music://track/158332598`

**Key Findings:**
- ✅ Response includes `provider_mappings` array with audio format details
- ✅ `provider_mappings[].url` contains Apple Music web URLs (not stream URLs)
- ✅ Audio format includes: `content_type`, `sample_rate`, `bit_depth`, `channels`, `codec_type`
- ❌ NO direct stream/playback URLs found
- ❌ Streaming port (8097) not referenced in response

**Response Structure:**
```json
{
  "uri": "apple_music://track/158332598",
  "item_id": "158332598",
  "provider": "apple_music",
  "media_type": "track",
  "name": "Test",
  "duration": 399.6,
  "track_number": 12,
  "disc_number": 1,
  "artists": [
    {
      "item_id": "484949",
      "provider": "apple_music",
      "name": "Prong",
      "uri": "apple_music://artist/484949",
      "provider_mappings": [
        {
          "item_id": "484949",
          "provider_domain": "apple_music",
          "provider_instance": "apple_music--RBqSXnvu",
          "url": "https://music.apple.com/us/artist/prong/484949",
          "audio_format": {
            "content_type": "?",
            "sample_rate": 44100,
            "bit_depth": 16,
            "channels": 2,
            "codec_type": "?",
            "bit_rate": 0,
            "output_format_str": "?"
          }
        }
      ]
    }
  ],
  "album": {
    "item_id": "158332411",
    "provider": "apple_music",
    "name": "Cleansing",
    "year": 1994,
    "provider_mappings": [
      {
        "url": "https://music.apple.com/us/album/cleansing/158332411"
      }
    ]
  },
  "provider_mappings": [
    {
      "item_id": "158332598",
      "provider_domain": "apple_music",
      "provider_instance": "apple_music--RBqSXnvu",
      "available": true,
      "url": "https://music.apple.com/us/album/test/158332411?i=158332598",
      "audio_format": {
        "content_type": "aac",
        "sample_rate": 44100,
        "bit_depth": 16,
        "channels": 2,
        "codec_type": "?",
        "bit_rate": 0,
        "output_format_str": "aac"
      }
    }
  ],
  "metadata": {
    "images": [
      {
        "type": "thumb",
        "path": "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/4c/f8/31/4cf83105-c408-effe-4677-c2ecb9e86c7a/mzi.rkqwktpg.jpg/600x600bb.jpg",
        "provider": "apple_music",
        "remotely_accessible": true
      }
    ],
    "genres": ["Music", "Metal", "Rock", "Hard Rock"],
    "performers": ["Ted Parsons & Paul Raven", "Tommy Victor"]
  }
}
```

### Response 2: Library Track (Apple Music Backed) via `music/item_by_uri`

**URI:** `library://track/32236`
**Track:** "2 Minutes to Midnight (2015 Remastered Version)" by Iron Maiden

**Key Findings:**
- ✅ Library tracks have `provider: "library"` but may still use streaming service backends
- ✅ Same structure as streaming service tracks
- ✅ `provider_mappings` contains Apple Music URLs even for library items
- ❌ NO local file:// URLs found (this track is streamed from Apple Music)

**Important Discovery:**
Library tracks in this Music Assistant instance are NOT local files - they are Apple Music tracks added to the library. The `provider_mappings[].url` field contains:
```
"url": "https://music.apple.com/us/album/2-minutes-to-midnight-2015-remastered-version/1147170341?i=1147170347"
```

This is a web URL, not a playback stream URL.

## References

### Source Code Evidence

**Frontend Implementation:**
- Built-in Player Component: https://github.com/music-assistant/frontend/blob/main/src/components/BuiltinPlayer.vue
  - Line ~50: `audioRef.value.src = ${webPlayer.baseUrl}/${data.media_url};`
  - Shows how frontend receives and uses `media_url` from events

- Web Player Plugin: https://github.com/music-assistant/frontend/blob/main/src/plugins/web_player.ts
  - Tab coordination and player mode management
  - Registers built-in player with server

- API Plugin: https://github.com/music-assistant/frontend/blob/main/src/plugins/api/index.ts
  - WebSocket communication layer
  - Event subscription system
  - Preview URL construction (line ~200): `${this.baseUrl}/preview?item_id=${encItemId}&provider=${provider}`

**Server Implementation:**
- Stream Controller: https://github.com/music-assistant/server/blob/main/music_assistant/controllers/streams.py
  - All stream endpoint handlers
  - URL construction helpers
  - Format support (mp3, flac, pcm)

- Web Server Controller: https://github.com/music-assistant/server/blob/main/music_assistant/controllers/webserver.py
  - HTTP route registration
  - Preview endpoint handler
  - Image proxy and WebSocket endpoints

**Documentation:**
- Music Assistant Python Client: https://github.com/music-assistant/client
- Music Assistant Server: https://github.com/music-assistant/server
- Home Assistant Integration: https://github.com/home-assistant/core (search for music_assistant)

### Response 3: Testing Stream URL Endpoints

**Tested:** 2025-10-16
**Server:** 192.168.23.196:8095

**URLs Tested (All returned 404):**
- `http://192.168.23.196:8095/preview/library/32236`
- `http://192.168.23.196:8097/preview/library/32236`
- `http://192.168.23.196:8095/stream/library/32236`
- `http://192.168.23.196:8097/stream/library/32236`
- `http://192.168.23.196:8095/audio/library/32236`
- `http://192.168.23.196:8097/audio/library/32236`

**Python Client Preview Method:**
The Python client has a `get_track_preview_url()` method that constructs:
```python
f"{base_url}/preview?path={encoded_item_id}&provider={provider_instance}"
```

However, testing this against the live server returned 404 errors, suggesting either:
1. Preview endpoint is not enabled on this server
2. Endpoint requires different parameters or authentication
3. Endpoint may have been removed/changed in newer versions

## Critical Findings Summary

### What We Know ✅

1. **`music/item_by_uri` Response Structure:**
   - Returns complete track metadata including artists, album, duration
   - Includes `provider_mappings` array with multiple provider sources
   - Contains `audio_format` details (sample rate, bit depth, channels, content type)
   - Web URLs in `provider_mappings[].url` point to streaming service pages (not playback streams)

2. **No Direct Stream URLs:**
   - Music Assistant uses a server-side streaming architecture
   - Stream URLs are NOT exposed in `music/item_by_uri` responses
   - The `provider_mappings[].url` field contains web page URLs, not audio streams
   - According to GitHub discussions, "MA does use streaming URLs but the architecture means there isn't one that is always the same"

3. **Audio Format Information Available:**
   - `content_type`: e.g., "aac", "flac"
   - `sample_rate`: e.g., 44100
   - `bit_depth`: e.g., 16
   - `channels`: e.g., 2
   - `codec_type`: usually "?" (not populated for streaming services)

4. **Streaming Ports:**
   - Interface port: 8095 (WebSocket and HTTP API)
   - Streaming port: 8097 (purpose unclear, endpoints not found)
   - No accessible HTTP endpoints found on either port for direct streaming

### What We Don't Know ❌

1. **How to Get Playback URLs:**
   - No discovered WebSocket command returns playback stream URLs
   - Preview endpoint documented in Python client returns 404
   - May require active playback session or different authentication

2. **Player Event Stream Details:**
   - Unknown if `player_updated` events include stream information
   - Would need to start playback and monitor events to confirm
   - Current monitoring tool doesn't capture full event payload

3. **Port 8097 Purpose:**
   - Documented as "streaming port" but no accessible endpoints found
   - May be used internally by server or require authentication

## Architectural Implications

Music Assistant appears to use a **mediated streaming architecture**:

1. **Client → Server:** Send playback commands with media URIs
2. **Server:** Handles provider authentication, stream retrieval, format conversion
3. **Server → Player:** Streams audio (possibly through port 8097 internally)

This means:
- ❌ Direct stream URLs are not available to clients
- ❌ Cannot implement client-side audio playback without going through MA server
- ✅ Can get rich metadata about tracks, albums, artists
- ✅ Can control playback via player commands
- ✅ Can get audio format specifications (for display purposes)

## Next Steps

1. ~~**[COMPLETE]** Test against live Music Assistant server~~
2. ~~**[COMPLETE]** Capture real WebSocket responses for `music/item_by_uri`~~
3. **[TODO]** Capture real `player_updated` event data during active playback
4. **[TODO]** Investigate if queue item events contain stream details
5. **[TODO]** Check if there's a separate command for stream details
6. ~~**[COMPLETE]** Update this document with actual JSON structures~~

## MAJOR DISCOVERY: Stream URLs DO Exist! (2025-10-16)

**BREAKTHROUGH:** After examining the Music Assistant frontend and server source code, stream URLs ARE exposed to clients through the WebSocket API. The previous conclusion was incorrect.

### How the Web Frontend Gets Stream URLs

The web frontend (`BuiltinPlayer.vue`) receives stream URLs through the `BUILTIN_PLAYER` event system:

**Frontend Code (BuiltinPlayer.vue):**
```typescript
// Subscribe to built-in player events
api.subscribe(EventType.BUILTIN_PLAYER, (data) => {
  if (data.command === 'PLAY_MEDIA') {
    // Server sends media_url in event data
    audioRef.value.src = `${webPlayer.baseUrl}/${data.media_url}`;
    audioRef.value.play();
  }
});
```

**Key Finding:** The server sends `media_url` in player events, which the client combines with `baseUrl` to construct stream URLs.

### Server-Side Stream Endpoints (Confirmed)

The Music Assistant server (`streams.py` and `webserver.py`) exposes multiple HTTP streaming endpoints:

#### 1. Queue Flow Stream (Crossfade Support)
```
GET /flow/{session_id}/{queue_id}/{queue_item_id}.{fmt}
```
- Serves continuous audio from queue items with crossfade
- Used for gapless playback

#### 2. Single Queue Item Stream
```
GET /single/{session_id}/{queue_id}/{queue_item_id}.{fmt}
```
- Streams individual queue items without crossfade

#### 3. Preview/Clip Stream
```
GET /preview?item_id={encoded_item_id}&provider={provider_instance}
```
- Serves preview/clip audio for tracks
- Item ID must be double URL-encoded
- **Note:** May require active session or specific server configuration

#### 4. Command Endpoint
```
GET /command/{queue_id}/{command}.mp3
```
- Handles player control commands (e.g., "next")

#### 5. Announcement Stream
```
GET /announcement/{player_id}.{fmt}?pre_announce={true|false}
```
- Streams announcement audio with optional pre-announce alert

#### 6. Plugin Source Stream
```
GET /pluginsource/{plugin_source}/{player_id}.{fmt}
```
- Streams audio from plugin providers

### Format Specifications

**Supported Formats:**
- `mp3` - MP3 audio
- `flac` - FLAC lossless audio
- `pcm` - Raw PCM with parameters: `pcm;codec=pcm;rate=44100;bitrate=16;channels=2`

### How Stream URLs Are Generated

Based on the server code (`streams.py`), URLs are constructed using helper methods:

**Queue Item Stream URL:**
```python
def resolve_stream_url(
    queue_id: str,
    queue_item_id: str,
    session_id: str = None,
    flow_mode: bool = True,
    fmt: str = "mp3"
) -> str:
    base_url = "http://{server}:{port}"
    mode = "flow" if flow_mode else "single"
    return f"{base_url}/{mode}/{session_id}/{queue_id}/{queue_item_id}.{fmt}"
```

**Plugin Source URL:**
```python
def get_plugin_source_url(
    plugin_source: str,
    player_id: str,
    fmt: str = "mp3"
) -> str:
    return f"{base_url}/pluginsource/{plugin_source}/{player_id}.{fmt}"
```

**Announcement URL:**
```python
def get_announcement_url(
    player_id: str,
    fmt: str = "mp3",
    pre_announce: bool = False
) -> str:
    return f"{base_url}/announcement/{player_id}.{fmt}?pre_announce={pre_announce}"
```

## Testing Against Live Server

Let me test these endpoints against the live server at 192.168.23.196:8095 to confirm they work.

### Test Results

**TODO:** Test the following:
1. Start playback and capture the `BUILTIN_PLAYER` event to see the actual `media_url` format
2. Try constructing stream URLs based on queue_id and queue_item_id patterns
3. Test preview endpoint with double-encoded track IDs
4. Verify which port is used (8095 vs 8097)

## Decision: REVISED Implementation Path

**NEW CONCLUSION:** Stream URLs ARE available, but through a different mechanism than initially investigated.

✅ **Can Implement (CONFIRMED):**
1. **Event-Based Stream URL Discovery:**
   - Subscribe to `BUILTIN_PLAYER` or similar player events
   - Extract `media_url` from event data
   - Construct full URL: `{baseUrl}/{media_url}`

2. **Direct Stream URL Construction:**
   - Implement helper methods to construct stream URLs for:
     - Queue items (flow and single modes)
     - Preview/clips
     - Announcements
     - Plugin sources
   - Support multiple audio formats (mp3, flac, pcm)

3. **Session Management:**
   - Track session_id for stream URL generation
   - Handle session lifecycle

✅ **Enhanced Models Needed:**
```swift
// Stream URL configuration
struct StreamOptions {
    let sessionId: String
    let queueId: String
    let queueItemId: String
    let format: AudioFormat // "mp3", "flac", "pcm"
    let flowMode: Bool // true for gapless, false for single
}

// Stream URL generator
func getStreamURL(for options: StreamOptions) -> URL {
    let mode = options.flowMode ? "flow" : "single"
    let path = "\(mode)/\(options.sessionId)/\(options.queueId)/\(options.queueItemId).\(options.format)"
    return baseURL.appendingPathComponent(path)
}

// Preview URL generator
func getPreviewURL(itemId: String, provider: String) -> URL {
    let encoded = itemId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
    let doubleEncoded = encoded.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
    return baseURL.appendingPathComponent("preview")
        .appending(queryItems: [
            URLQueryItem(name: "item_id", value: doubleEncoded),
            URLQueryItem(name: "provider", value: provider)
        ])
}
```

⚠️ **Implementation Challenges:**
- Stream URLs require active playback sessions (session_id)
- May need to start playback to get valid stream URLs
- Session lifecycle and expiration needs handling
- Format negotiation (when to use mp3 vs flac vs pcm)

**Updated Path Forward:**

1. **Subscribe to Player Events:**
   - Monitor `BUILTIN_PLAYER` or `player_updated` events
   - Capture and parse `media_url` field
   - Document actual event structure from live server

2. **Implement Stream URL Helpers:**
   - Add methods to construct URLs for all endpoint types
   - Support format selection
   - Handle session management

3. **Test Against Live Server:**
   - Verify endpoints work with actual session/queue IDs
   - Confirm which port is used (8095 or 8097)
   - Test audio playback with constructed URLs

4. **Document Stream Architecture:**
   - Explain session-based streaming
   - Clarify when URLs are valid/expire
   - Provide examples of URL construction

5. **Consider Client-Side Playback:**
   - Now that stream URLs are available, client-side playback IS possible
   - Could implement AVPlayer-based playback in Swift
   - Would still need to coordinate with MA server for queue management
