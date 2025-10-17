# ma-stream - Stream URL Monitor

Monitor Music Assistant BUILTIN_PLAYER events and display streaming URLs in real-time.

## Overview

`ma-stream` is a CLI tool that connects to your Music Assistant server and monitors BUILTIN_PLAYER events, displaying stream URLs as they arrive. It's useful for:

- Debugging streaming issues
- Monitoring what's being played
- Extracting stream URLs for testing
- Integration with other tools via JSON output

## Usage

```bash
# Monitor with default settings
ma-stream

# Specify custom host/port
ma-stream --host 192.168.23.196 --port 8095

# Disable URL accessibility testing
ma-stream --no-test

# Output as JSON for scripting
ma-stream --json

# Show help
ma-stream --help
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--host <host>` | Music Assistant host address | `192.168.23.196` |
| `--port <port>` | Music Assistant port | `8095` |
| `--no-test` | Disable URL accessibility testing | Testing enabled |
| `--json` | Output as JSON instead of formatted text | Text mode |
| `--verbose` | Show all events (not just PLAY_MEDIA) | Non-verbose |

## Output Formats

### Text Mode (default)

When running in text mode, `ma-stream` displays colorful, human-readable output:

```
🎵 Connecting to Music Assistant at 192.168.23.196:8095...
✓ Connected

Monitoring for BUILTIN_PLAYER events...
Press Ctrl+C to stop

[12:34:56] PLAY_MEDIA event received
  Queue: player_builtin_12345
  Item:  67890

  Stream URL:
  http://192.168.23.196:8095/flow/session-abc/player_builtin_12345/67890.mp3

  Format: mp3
  Mode:   flow (gapless)
  Status: ✓ Accessible (200 OK)
```

The status line shows:
- **✓ Accessible (200 OK)** - URL is reachable via HTTP HEAD request
- **✗ Failed (404)** - URL returned an error status code
- **✗ Error (...)** - Network error or timeout

### JSON Mode

JSON mode outputs one JSON object per event for easy parsing:

```json
{
  "timestamp": "2025-10-16T12:34:56Z",
  "command": "PLAY_MEDIA",
  "stream_url": "http://192.168.23.196:8095/flow/session-abc/queue456/item789.mp3",
  "queue_id": "queue456",
  "queue_item_id": "item789",
  "format": "mp3"
}
```

When URL testing is enabled, a second JSON object is emitted with test results:

```json
{
  "url": "http://192.168.23.196:8095/flow/session-abc/queue456/item789.mp3",
  "status_code": 200,
  "response_time": 0.123,
  "accessible": true
}
```

## Features

### Automatic URL Testing

By default, `ma-stream` tests each URL with an HTTP HEAD request to verify accessibility. This helps identify:

- Network connectivity issues
- Server configuration problems
- Invalid stream paths
- Timeout issues

Testing adds a small delay (~50-200ms per URL) but provides valuable diagnostic information. Disable with `--no-test` for faster operation.

### Stream Modes

`ma-stream` automatically detects and displays the streaming mode:

- **flow (gapless)** - Flow mode for gapless playback (`/flow/...`)
- **single** - Single track mode (`/single/...`)

### Color Support

Text mode automatically detects terminal capabilities and enables ANSI colors when:
- Running in an interactive terminal (not piped)
- Not in JSON mode

Colors are used to highlight:
- Command names (blue)
- Success status (green)
- Error status (red)

## Examples

### Monitor and copy URLs to clipboard (macOS)

```bash
ma-stream --json | jq -r '.stream_url' | pbcopy
```

### Save URLs to file

```bash
ma-stream --json >> stream-urls.jsonl
```

### Test URLs with curl

```bash
ma-stream --json --no-test | jq -r '.stream_url' | while read url; do
  echo "Testing: $url"
  curl -I "$url"
done
```

### Monitor remote server

```bash
ma-stream --host music-assistant.local --port 8095
```

### Quick URL extraction

```bash
# Just print URLs, no testing or metadata
ma-stream --json --no-test | jq -r '.stream_url'
```

## How It Works

1. **Connects** to Music Assistant via WebSocket
2. **Subscribes** to BUILTIN_PLAYER events
3. **Filters** for PLAY_MEDIA commands
4. **Extracts** the media URL from the event
5. **Constructs** the full streaming URL
6. **Tests** URL accessibility (optional)
7. **Formats** and displays the information

## Troubleshooting

### Connection refused

```
Error: Connection refused
```

- Verify Music Assistant is running
- Check host and port settings
- Ensure firewall allows WebSocket connections

### No events appearing

- Start playing music in Music Assistant
- `ma-stream` only shows PLAY_MEDIA events
- Use `--verbose` to see all events (future feature)

### URL not accessible

If URLs show as not accessible:

1. Check Music Assistant server logs
2. Verify network connectivity
3. Try accessing URL directly with curl
4. Check firewall rules on server

### JSON parsing errors

- Ensure you're using `--json` flag
- Pipe to `jq` for validation: `ma-stream --json | jq .`

## Integration

### With jq

```bash
# Extract specific fields
ma-stream --json | jq '{url: .stream_url, format: .format}'

# Filter by format
ma-stream --json | jq 'select(.format == "flac")'
```

### With AVPlayer (Swift)

```swift
// Start ma-stream in background
let process = Process()
process.executableURL = URL(fileURLWithPath: "/path/to/ma-stream")
process.arguments = ["--json", "--no-test"]

let pipe = Pipe()
process.standardOutput = pipe

process.launch()

// Read JSON output
Task {
    for try await line in pipe.fileHandleForReading.bytes.lines {
        if let data = line.data(using: .utf8),
           let json = try? JSONDecoder().decode(StreamEvent.self, from: data) {
            let player = AVPlayer(url: URL(string: json.stream_url)!)
            player.play()
        }
    }
}
```

## Performance

- **Connection time**: ~100-500ms
- **Event latency**: <50ms from Music Assistant event
- **URL testing**: 50-200ms per URL (disable with `--no-test`)
- **Memory usage**: ~5-10MB

## Limitations

- Only monitors BUILTIN_PLAYER events (not all player types)
- Only displays PLAY_MEDIA commands by default
- URL testing uses HTTP HEAD (some servers may not support)
- No filtering by queue or player ID (future enhancement)

## See Also

- [Streaming Audio URLs Documentation](../streaming-audio-urls.md) - Full guide to stream URLs
- [MusicAssistantKit API](../../README.md) - Swift library documentation
