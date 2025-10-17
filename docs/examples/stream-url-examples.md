# Music Assistant Stream URL Examples

**Date:** 2025-10-16
**Server:** Music Assistant 2.7.0b3
**Ports:** Interface (8095), Streaming (varies by endpoint)

## Overview

Music Assistant exposes HTTP streaming endpoints that can be accessed once you have the required IDs (session_id, queue_id, queue_item_id, player_id). These URLs are typically obtained through WebSocket events rather than being queried directly.

## Stream URL Patterns

### 1. Queue Flow Stream (Gapless Playback)

**Pattern:**
```
GET http://{server}:{port}/flow/{session_id}/{queue_id}/{queue_item_id}.{format}
```

**Example:**
```
http://192.168.23.196:8095/flow/abc123/queue_player_builtin/1234567.mp3
```

**Usage:** Continuous audio streaming with crossfade support. Used when playing through a queue with gapless transitions.

**Formats:** `mp3`, `flac`, `pcm`

---

### 2. Single Queue Item Stream

**Pattern:**
```
GET http://{server}:{port}/single/{session_id}/{queue_id}/{queue_item_id}.{format}
```

**Example:**
```
http://192.168.23.196:8095/single/abc123/queue_player_builtin/1234567.mp3
```

**Usage:** Individual queue item streaming without crossfade. Used for standalone track playback.

**Formats:** `mp3`, `flac`, `pcm`

---

### 3. Preview/Clip Stream

**Pattern:**
```
GET http://{server}:{port}/preview?item_id={double_encoded_id}&provider={provider_instance}
```

**Example:**
```
http://192.168.23.196:8095/preview?item_id=158332598&provider=apple_music--RBqSXnvu
```

**Notes:**
- Item ID should be double URL-encoded in some implementations
- May require active session or authentication
- Typically serves 30-second previews

---

### 4. Command Endpoint

**Pattern:**
```
GET http://{server}:{port}/command/{queue_id}/{command}.mp3
```

**Example:**
```
http://192.168.23.196:8095/command/queue_player_builtin/next.mp3
```

**Usage:** Trigger player commands via HTTP request. Always returns MP3 format.

**Commands:** `next`, `previous`, `pause`, `play`, etc.

---

### 5. Announcement Stream

**Pattern:**
```
GET http://{server}:{port}/announcement/{player_id}.{format}?pre_announce={true|false}
```

**Example:**
```
http://192.168.23.196:8095/announcement/player_builtin.mp3?pre_announce=true
```

**Usage:** Stream announcement audio to a player with optional pre-announce alert sound.

**Formats:** `mp3`, `flac`

---

### 6. Plugin Source Stream

**Pattern:**
```
GET http://{server}:{port}/pluginsource/{plugin_source}/{player_id}.{format}
```

**Example:**
```
http://192.168.23.196:8095/pluginsource/airplay/player_builtin.mp3
```

**Usage:** Stream audio from plugin providers (e.g., AirPlay, Radio Browser).

**Formats:** `mp3`, `flac`, `pcm`

---

## Format Specifications

### Audio Formats

1. **MP3:**
   - Extension: `.mp3`
   - Most compatible
   - Moderate quality
   - Lower bandwidth

2. **FLAC:**
   - Extension: `.flac`
   - Lossless quality
   - Higher bandwidth
   - Best for high-quality audio

3. **PCM (Raw):**
   - Extension: `.pcm`
   - Format string: `pcm;codec=pcm;rate=44100;bitrate=16;channels=2`
   - Uncompressed audio
   - Highest bandwidth
   - Parameters in format string:
     - `rate`: Sample rate (e.g., 44100, 48000)
     - `bitrate`: Bit depth (e.g., 16, 24)
     - `channels`: Channel count (e.g., 2 for stereo)

### Format Negotiation

The client can request different formats based on:
- Available bandwidth
- Device capabilities
- User preferences
- Battery/power considerations

## How Stream URLs Are Obtained

### Method 1: WebSocket Events (Recommended)

Stream URLs are typically delivered through WebSocket events:

**Event Type:** `BUILTIN_PLAYER` (or similar player-specific events)

**Event Data Structure:**
```json
{
  "command": "PLAY_MEDIA",
  "media_url": "flow/abc123/queue_player_builtin/1234567.mp3",
  "player_id": "player_builtin",
  "queue_id": "queue_player_builtin"
}
```

**Client Implementation:**
```javascript
// Subscribe to built-in player events
api.subscribe("builtin_player", (data) => {
  if (data.command === "PLAY_MEDIA") {
    const fullUrl = `${baseUrl}/${data.media_url}`;
    audioElement.src = fullUrl;
    audioElement.play();
  }
});
```

**Swift Equivalent:**
```swift
client.events.subscribe(to: .builtinPlayer) { event in
    if event.command == "PLAY_MEDIA",
       let mediaUrl = event.mediaUrl {
        let fullUrl = client.baseURL.appendingPathComponent(mediaUrl)
        playAudio(from: fullUrl)
    }
}
```

### Method 2: Construct URLs Manually

If you have the required IDs (from player state or queue events), you can construct URLs:

```swift
struct StreamURLBuilder {
    let baseURL: URL

    func queueFlowURL(
        sessionId: String,
        queueId: String,
        queueItemId: String,
        format: String = "mp3"
    ) -> URL {
        baseURL
            .appendingPathComponent("flow")
            .appendingPathComponent(sessionId)
            .appendingPathComponent(queueId)
            .appendingPathComponent("\(queueItemId).\(format)")
    }

    func queueSingleURL(
        sessionId: String,
        queueId: String,
        queueItemId: String,
        format: String = "mp3"
    ) -> URL {
        baseURL
            .appendingPathComponent("single")
            .appendingPathComponent(sessionId)
            .appendingPathComponent(queueId)
            .appendingPathComponent("\(queueItemId).\(format)")
    }

    func previewURL(
        itemId: String,
        provider: String
    ) -> URL {
        // Double encode item ID
        let encoded = itemId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? itemId
        let doubleEncoded = encoded.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? encoded

        var components = URLComponents(url: baseURL.appendingPathComponent("preview"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "item_id", value: doubleEncoded),
            URLQueryItem(name: "provider", value: provider)
        ]
        return components.url!
    }
}
```

## Session Management

### Session Lifecycle

1. **Session Creation:**
   - Sessions are created server-side when playback starts
   - Session ID is included in player events
   - Session ID is required for queue stream URLs

2. **Session Duration:**
   - Sessions persist during active playback
   - May expire after inactivity (timeout varies)
   - New playback typically creates new session

3. **Session Tracking:**
   - Track session_id from player events
   - Update session_id when it changes
   - Handle session expiration gracefully

### Example Session Flow

```
1. Client: Send play_media command
   → WebSocket: player_queues/play_media

2. Server: Creates session, starts streaming
   ← Event: player_updated (includes session_id)

3. Server: Sends built-in player event
   ← Event: builtin_player (includes media_url)

4. Client: Constructs full URL
   → HTTP GET: http://server:8095/flow/{session_id}/...

5. Server: Streams audio chunks
   ← HTTP Response: audio/mpeg (chunked)
```

## Testing Stream URLs

### Prerequisites

1. Music Assistant server running
2. At least one player configured
3. Media in library or streaming service connected
4. Active playback session (for session_id)

### Test Plan

#### Test 1: Capture Player Events

```bash
# Connect WebSocket and monitor events
wscat -c ws://192.168.23.196:8095/ws

# Send command to start playback
{
  "message_id": "test-1",
  "command": "player_queues/play_media",
  "args": {
    "queue_id": "queue_player_builtin",
    "uri": "library://track/32236"
  }
}

# Watch for events containing media_url or session_id
```

#### Test 2: Test Preview Endpoint

```bash
# Try preview URL (may require active session)
curl -v "http://192.168.23.196:8095/preview?item_id=32236&provider=library"

# Try with Apple Music track
curl -v "http://192.168.23.196:8095/preview?item_id=158332598&provider=apple_music--RBqSXnvu"
```

#### Test 3: Test Queue Stream (Requires Valid IDs)

```bash
# Replace with actual session_id, queue_id, queue_item_id from events
curl -v "http://192.168.23.196:8095/single/SESSION_ID/queue_player_builtin/QUEUE_ITEM_ID.mp3"
```

### Expected Results

- **Preview endpoint:** May return 404 if not enabled or requires session
- **Queue streams:** Return 404 without valid session/queue IDs
- **Command endpoint:** Should work with valid queue_id
- **Announcement endpoint:** Should work with valid player_id

### Notes for Live Testing

1. **Port Selection:**
   - Interface/API: Port 8095
   - Streaming: May also use port 8095 (not separate 8097)
   - Check server logs for actual port configuration

2. **Authentication:**
   - Local network access typically unrestricted
   - Remote access may require authentication
   - Check server configuration for auth requirements

3. **CORS:**
   - Web players may encounter CORS restrictions
   - Use same-origin requests when possible
   - Check CORS headers in server responses

## Implementation Recommendations

### For MusicAssistantKit

1. **Event Subscription:**
   ```swift
   // Add event type for built-in player events
   enum EventType: String, Codable {
       case playerUpdated = "player_updated"
       case queueItemsUpdated = "queue_items_updated"
       case builtinPlayer = "builtin_player"  // NEW
   }

   // Parse media_url from event data
   struct BuiltinPlayerEvent: Codable {
       let command: String  // "PLAY_MEDIA", "PAUSE", etc.
       let mediaUrl: String?  // "flow/{session}/{queue}/{item}.mp3"
       let playerId: String
       let queueId: String
   }
   ```

2. **Stream URL Builder:**
   ```swift
   extension MusicAssistantClient {
       func getStreamURL(from mediaUrl: String) -> URL {
           baseURL.appendingPathComponent(mediaUrl)
       }

       func buildPreviewURL(itemId: String, provider: String) -> URL {
           // Implementation from examples above
       }
   }
   ```

3. **AVPlayer Integration:**
   ```swift
   import AVFoundation

   class MusicAssistantPlayer: ObservableObject {
       private let client: MusicAssistantClient
       private var player: AVPlayer?

       func playFromEvent(_ event: BuiltinPlayerEvent) {
           guard let mediaUrl = event.mediaUrl else { return }
           let streamUrl = client.getStreamURL(from: mediaUrl)

           let playerItem = AVPlayerItem(url: streamUrl)
           player = AVPlayer(playerItem: playerItem)
           player?.play()
       }
   }
   ```

## Next Steps for Testing

1. **Capture Real Events:**
   - Connect to 192.168.23.196:8095
   - Start playback
   - Monitor WebSocket for `builtin_player` events
   - Document actual event structure

2. **Test Stream URLs:**
   - Extract session_id and queue_item_id from events
   - Construct stream URLs using patterns above
   - Test with curl or AVPlayer
   - Verify audio playback works

3. **Document Findings:**
   - Record actual event JSON
   - Note any differences from expected format
   - Document which endpoints work
   - Update implementation plan accordingly
