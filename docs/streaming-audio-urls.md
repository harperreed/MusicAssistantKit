# Streaming Audio URLs

MusicAssistantKit provides access to Music Assistant's streaming audio endpoints for client-side playback.

## Overview

Music Assistant exposes HTTP streaming endpoints that clients can use for direct audio playback. Stream URLs are obtained through WebSocket events rather than direct queries.

## Architecture

1. **Server sends `BUILTIN_PLAYER` events** containing `media_url` paths
2. **Client constructs full URLs** by combining base URL + media path
3. **Client streams audio** via standard HTTP requests (AVPlayer, URLSession, etc.)

## Getting Stream URLs from Events

Subscribe to built-in player events to receive stream URLs when playback starts:

```swift
import Combine

var cancellables = Set<AnyCancellable>()

client.events.builtinPlayerEvents.sink { event in
    guard event.command == .playMedia,
          let mediaUrl = event.mediaUrl else { return }

    // Construct full stream URL
    let streamURL = client.getStreamURL(mediaPath: mediaUrl)

    // Use with AVPlayer
    let player = AVPlayer(url: streamURL.url)
    player.play()
}.store(in: &cancellables)
```

## Stream URL Types

Music Assistant provides several streaming endpoints:

### 1. Queue Flow Stream (Gapless Playback)

```swift
let streamURL = client.constructQueueStreamURL(
    sessionId: "session-id",
    queueId: "queue-id",
    queueItemId: "item-id",
    format: .mp3,
    flowMode: true  // gapless with crossfade
)
```

URL format: `http://server:8095/flow/{session}/{queue}/{item}.mp3`

### 2. Single Item Stream

```swift
let streamURL = client.constructQueueStreamURL(
    sessionId: "session-id",
    queueId: "queue-id",
    queueItemId: "item-id",
    format: .flac,
    flowMode: false  // single item
)
```

URL format: `http://server:8095/single/{session}/{queue}/{item}.flac`

### 3. Preview/Clip Stream

```swift
let streamURL = client.constructPreviewURL(
    itemId: "track-id",
    provider: "library"
)
```

URL format: `http://server:8095/preview?item_id={double-encoded-id}&provider={provider}`

### 4. Announcement Stream

```swift
let streamURL = client.constructAnnouncementURL(
    playerId: "player-id",
    format: .mp3,
    preAnnounce: true
)
```

URL format: `http://server:8095/announcement/{player}.mp3?pre_announce=true`

### 5. Plugin Source Stream

```swift
let streamURL = client.constructPluginSourceURL(
    pluginSource: "airplay",
    playerId: "player-id",
    format: .flac
)
```

URL format: `http://server:8095/pluginsource/{plugin}/{player}.flac`

## Audio Formats

Supported formats:
- `.mp3` - MP3 audio
- `.flac` - FLAC lossless
- `.pcm` - Raw PCM (requires additional parameters)

## Example: AVPlayer Integration

```swift
import AVFoundation
import Combine

class MusicAssistantPlayer {
    private let client: MusicAssistantClient
    private let avPlayer = AVPlayer()
    private var cancellables = Set<AnyCancellable>()

    init(client: MusicAssistantClient) {
        self.client = client
        setupStreamListener()
    }

    private func setupStreamListener() {
        client.events.builtinPlayerEvents.sink { [weak self] event in
            guard let self = self,
                  event.command == .playMedia,
                  let mediaUrl = event.mediaUrl else { return }

            let streamURL = self.client.getStreamURL(mediaPath: mediaUrl)
            let playerItem = AVPlayerItem(url: streamURL.url)
            self.avPlayer.replaceCurrentItem(with: playerItem)
            self.avPlayer.play()
        }.store(in: &cancellables)
    }

    func pause() {
        avPlayer.pause()
    }

    func resume() {
        avPlayer.play()
    }
}
```

## Session Management

Stream URLs require active playback sessions. The `sessionId` is managed by Music Assistant and included in event data.

**Important:**
- Stream URLs are session-specific
- URLs may expire when sessions end
- Always use fresh URLs from events for reliability

## Limitations

1. **Preview endpoints** may not be enabled on all servers
2. **Session-based URLs** expire - don't cache long-term
3. **DRM content** may have additional restrictions
4. **Format availability** depends on server configuration

## Testing

Run integration tests against a live server:

```bash
MA_TEST_HOST=192.168.23.196 MA_TEST_PORT=8095 swift test --filter StreamingIntegrationTests
```
