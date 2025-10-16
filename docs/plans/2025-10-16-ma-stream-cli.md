# ma-stream CLI Tool Implementation Plan

> **For Claude:** Use `${SUPERPOWERS_SKILLS_ROOT}/skills/collaboration/executing-plans/SKILL.md` to implement this plan task-by-task.

**Goal:** Build a CLI tool that monitors BUILTIN_PLAYER events and displays stream URLs with accessibility testing.

**Architecture:** Simple single-purpose CLI using MusicAssistantKit for event subscription, URLSession for HTTP testing, and ArgumentParser for CLI interface. Formats output with ANSI colors and supports JSON mode for scripting.

**Tech Stack:** Swift 6.0, MusicAssistantKit, ArgumentParser, Foundation (URLSession)

---

## Task 1: URLTester Component

**Files:**
- Create: `Sources/MAStream/URLTester.swift`
- Test: `Tests/MAStreamTests/URLTesterTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/MAStreamTests/URLTesterTests.swift
// ABOUTME: Unit tests for URLTester HTTP accessibility checking
// ABOUTME: Validates HEAD requests, status code handling, and timeout behavior

import XCTest
@testable import MAStream

final class URLTesterTests: XCTestCase {
    func testAccessibleURL() async throws {
        let tester = URLTester()

        let result = await tester.test(url: URL(string: "https://httpbin.org/status/200")!)

        XCTAssertEqual(result.statusCode, 200)
        XCTAssertTrue(result.isAccessible)
        XCTAssertGreaterThan(result.responseTime, 0)
    }

    func testInaccessibleURL() async throws {
        let tester = URLTester()

        let result = await tester.test(url: URL(string: "https://httpbin.org/status/404")!)

        XCTAssertEqual(result.statusCode, 404)
        XCTAssertFalse(result.isAccessible)
    }

    func testTimeout() async throws {
        let tester = URLTester(timeout: 0.1)

        let result = await tester.test(url: URL(string: "https://httpbin.org/delay/5")!)

        XCTAssertNil(result.statusCode)
        XCTAssertFalse(result.isAccessible)
        XCTAssertNotNil(result.error)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter URLTesterTests
```

Expected: FAIL with "No such module 'MAStream'"

**Step 3: Add MAStream target to Package.swift**

```swift
// Package.swift
// Add to targets array:
.executableTarget(
    name: "MAStream",
    dependencies: [
        "MusicAssistantKit",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
    ]
),
.testTarget(
    name: "MAStreamTests",
    dependencies: ["MAStream"]
)
```

**Step 4: Implement URLTester**

```swift
// Sources/MAStream/URLTester.swift
// ABOUTME: HTTP HEAD request tester for stream URL accessibility
// ABOUTME: Returns status code, timing, and error information

import Foundation

public struct TestResult {
    public let url: URL
    public let statusCode: Int?
    public let responseTime: TimeInterval
    public let error: Error?

    public var isAccessible: Bool {
        guard let code = statusCode else { return false }
        return (200...299).contains(code)
    }
}

public actor URLTester {
    private let session: URLSession
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 5.0) {
        self.timeout = timeout

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.httpMaximumConnectionsPerHost = 1
        self.session = URLSession(configuration: config)
    }

    public func test(url: URL) async -> TestResult {
        let startTime = Date()

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout

        do {
            let (_, response) = try await session.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let responseTime = Date().timeIntervalSince(startTime)

            return TestResult(
                url: url,
                statusCode: httpResponse?.statusCode,
                responseTime: responseTime,
                error: nil
            )
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return TestResult(
                url: url,
                statusCode: nil,
                responseTime: responseTime,
                error: error
            )
        }
    }
}
```

**Step 5: Run test to verify it passes**

```bash
swift test --filter URLTesterTests
```

Expected: PASS (all 3 tests)

**Step 6: Commit**

```bash
git add Package.swift Sources/MAStream/URLTester.swift Tests/MAStreamTests/URLTesterTests.swift
git commit -m "feat: add URLTester for stream accessibility checking

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: OutputFormatter Component

**Files:**
- Create: `Sources/MAStream/OutputFormatter.swift`
- Test: `Tests/MAStreamTests/OutputFormatterTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/MAStreamTests/OutputFormatterTests.swift
// ABOUTME: Unit tests for OutputFormatter ANSI color and JSON output
// ABOUTME: Validates formatting of stream events and test results

import XCTest
@testable import MAStream
import MusicAssistantKit

final class OutputFormatterTests: XCTestCase {
    func testFormatStreamEvent() {
        let formatter = OutputFormatter(jsonMode: false, colorEnabled: false)
        let event = BuiltinPlayerEvent(
            command: .playMedia,
            mediaUrl: "flow/session123/queue456/item789.mp3",
            queueId: "queue456",
            queueItemId: "item789"
        )

        let output = formatter.formatStreamEvent(event, streamURL: "http://localhost:8095/flow/session123/queue456/item789.mp3")

        XCTAssertTrue(output.contains("PLAY_MEDIA"))
        XCTAssertTrue(output.contains("queue456"))
        XCTAssertTrue(output.contains("item789"))
        XCTAssertTrue(output.contains("http://localhost:8095"))
        XCTAssertTrue(output.contains("mp3"))
    }

    func testFormatTestResult() {
        let formatter = OutputFormatter(jsonMode: false, colorEnabled: false)
        let result = TestResult(
            url: URL(string: "http://localhost:8095/test.mp3")!,
            statusCode: 200,
            responseTime: 0.123,
            error: nil
        )

        let output = formatter.formatTestResult(result)

        XCTAssertTrue(output.contains("200"))
        XCTAssertTrue(output.contains("Accessible"))
    }

    func testJSONMode() throws {
        let formatter = OutputFormatter(jsonMode: true, colorEnabled: false)
        let event = BuiltinPlayerEvent(
            command: .playMedia,
            mediaUrl: "flow/session/queue/item.mp3",
            queueId: "queue",
            queueItemId: "item"
        )

        let output = formatter.formatStreamEvent(event, streamURL: "http://localhost:8095/flow/session/queue/item.mp3")

        // Should be valid JSON
        let json = try JSONSerialization.jsonObject(with: output.data(using: .utf8)!) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["command"] as? String, "PLAY_MEDIA")
        XCTAssertEqual(json?["stream_url"] as? String, "http://localhost:8095/flow/session/queue/item.mp3")
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter OutputFormatterTests
```

Expected: FAIL with "Type 'OutputFormatter' not found"

**Step 3: Implement OutputFormatter**

```swift
// Sources/MAStream/OutputFormatter.swift
// ABOUTME: Formats stream events and test results for console or JSON output
// ABOUTME: Supports ANSI colors and JSON mode for scripting

import Foundation
import MusicAssistantKit

public struct OutputFormatter {
    private let jsonMode: Bool
    private let colorEnabled: Bool

    public init(jsonMode: Bool, colorEnabled: Bool) {
        self.jsonMode = jsonMode
        self.colorEnabled = colorEnabled
    }

    public func formatStreamEvent(_ event: BuiltinPlayerEvent, streamURL: String) -> String {
        if jsonMode {
            return formatJSON(event: event, streamURL: streamURL)
        } else {
            return formatText(event: event, streamURL: streamURL)
        }
    }

    public func formatTestResult(_ result: TestResult) -> String {
        if jsonMode {
            return formatJSON(result: result)
        } else {
            return formatText(result: result)
        }
    }

    private func formatText(event: BuiltinPlayerEvent, streamURL: String) -> String {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let command = color(event.command.rawValue, .blue)

        var output = """

        [\(timestamp)] \(command) event received
        """

        if let queueId = event.queueId {
            output += "\n  Queue: \(queueId)"
        }

        if let itemId = event.queueItemId {
            output += "\n  Item:  \(itemId)"
        }

        output += """


          Stream URL:
          \(streamURL)

        """

        // Parse format from URL
        if let format = extractFormat(from: streamURL) {
            output += "  Format: \(format)\n"
        }

        // Parse mode (flow/single)
        if streamURL.contains("/flow/") {
            output += "  Mode:   flow (gapless)\n"
        } else if streamURL.contains("/single/") {
            output += "  Mode:   single\n"
        }

        return output
    }

    private func formatText(result: TestResult) -> String {
        if result.isAccessible {
            let status = color("✓ Accessible", .green)
            return "  Status: \(status) (\(result.statusCode!) OK)\n"
        } else if let error = result.error {
            let status = color("✗ Error", .red)
            return "  Status: \(status) (\(error.localizedDescription))\n"
        } else {
            let status = color("✗ Failed", .red)
            return "  Status: \(status) (\(result.statusCode ?? 0))\n"
        }
    }

    private func formatJSON(event: BuiltinPlayerEvent, streamURL: String) -> String {
        let dict: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "command": event.command.rawValue,
            "stream_url": streamURL,
            "queue_id": event.queueId as Any,
            "queue_item_id": event.queueItemId as Any,
            "format": extractFormat(from: streamURL) as Any
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private func formatJSON(result: TestResult) -> String {
        let dict: [String: Any] = [
            "url": result.url.absoluteString,
            "status_code": result.statusCode as Any,
            "response_time": result.responseTime,
            "accessible": result.isAccessible,
            "error": result.error?.localizedDescription as Any
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private func extractFormat(from url: String) -> String? {
        let components = url.split(separator: ".")
        return components.last.map(String.init)
    }

    private func color(_ text: String, _ code: ANSIColor) -> String {
        guard colorEnabled else { return text }
        return "\u{001B}[\(code.rawValue)m\(text)\u{001B}[0m"
    }

    private enum ANSIColor: Int {
        case red = 31
        case green = 32
        case blue = 34
    }
}
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter OutputFormatterTests
```

Expected: PASS (all 3 tests)

**Step 5: Commit**

```bash
git add Sources/MAStream/OutputFormatter.swift Tests/MAStreamTests/OutputFormatterTests.swift
git commit -m "feat: add OutputFormatter for stream event display

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: StreamMonitor Core Logic

**Files:**
- Create: `Sources/MAStream/StreamMonitor.swift`
- Test: `Tests/MAStreamTests/StreamMonitorTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/MAStreamTests/StreamMonitorTests.swift
// ABOUTME: Unit tests for StreamMonitor event subscription and URL extraction
// ABOUTME: Uses MockWebSocketConnection to simulate BUILTIN_PLAYER events

import XCTest
import Combine
@testable import MAStream
@testable import MusicAssistantKit

final class StreamMonitorTests: XCTestCase {
    func testMonitorReceivesEvents() async throws {
        let mockConnection = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mockConnection)
        try await client.connect()

        let monitor = StreamMonitor(client: client, testURLs: false)

        let expectation = expectation(description: "Receive stream event")
        var receivedURL: String?

        let task = Task {
            for await streamInfo in monitor.streamEvents {
                receivedURL = streamInfo.url
                expectation.fulfill()
            }
        }

        // Simulate BUILTIN_PLAYER event
        mockConnection.simulateBuiltinPlayerEvent(
            command: "PLAY_MEDIA",
            mediaUrl: "flow/session123/queue456/item789.mp3",
            queueId: "queue456",
            queueItemId: "item789"
        )

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertNotNil(receivedURL)
        XCTAssertTrue(receivedURL!.contains("flow/session123/queue456/item789.mp3"))

        task.cancel()
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter StreamMonitorTests
```

Expected: FAIL with "Type 'StreamMonitor' not found"

**Step 3: Implement StreamMonitor**

```swift
// Sources/MAStream/StreamMonitor.swift
// ABOUTME: Monitors BUILTIN_PLAYER events and extracts stream URLs
// ABOUTME: Provides AsyncStream of stream information for consumption

import Foundation
import MusicAssistantKit
import Combine

public struct StreamInfo {
    public let event: BuiltinPlayerEvent
    public let url: String
    public let testResult: TestResult?
}

public actor StreamMonitor {
    private let client: MusicAssistantClient
    private let urlTester: URLTester?
    private var cancellables = Set<AnyCancellable>()

    public init(client: MusicAssistantClient, testURLs: Bool = true, timeout: TimeInterval = 5.0) {
        self.client = client
        self.urlTester = testURLs ? URLTester(timeout: timeout) : nil
    }

    public var streamEvents: AsyncStream<StreamInfo> {
        AsyncStream { continuation in
            Task {
                let events = await client.events

                events.builtinPlayerEvents.sink { [weak self] event in
                    guard let self = self else { return }

                    Task {
                        await self.handleEvent(event, continuation: continuation)
                    }
                }.store(in: &cancellables)

                continuation.onTermination = { @Sendable _ in
                    // Cleanup if needed
                }
            }
        }
    }

    private func handleEvent(_ event: BuiltinPlayerEvent, continuation: AsyncStream<StreamInfo>.Continuation) async {
        guard event.command == .playMedia,
              let mediaUrl = event.mediaUrl else {
            return
        }

        do {
            let streamURL = try client.getStreamURL(mediaPath: mediaUrl)

            var testResult: TestResult?
            if let tester = urlTester {
                testResult = await tester.test(url: streamURL.url)
            }

            let info = StreamInfo(
                event: event,
                url: streamURL.url.absoluteString,
                testResult: testResult
            )

            continuation.yield(info)
        } catch {
            // Skip events we can't process
            return
        }
    }
}
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter StreamMonitorTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add Sources/MAStream/StreamMonitor.swift Tests/MAStreamTests/StreamMonitorTests.swift
git commit -m "feat: add StreamMonitor for event processing

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: CLI Entry Point

**Files:**
- Create: `Sources/MAStream/main.swift`

**Step 1: Implement CLI with ArgumentParser**

```swift
// Sources/MAStream/main.swift
// ABOUTME: CLI entry point for ma-stream tool
// ABOUTME: Monitors BUILTIN_PLAYER events and displays stream URLs

import Foundation
import ArgumentParser
import MusicAssistantKit

@main
struct MAStreamCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ma-stream",
        abstract: "Monitor Music Assistant streaming URLs",
        discussion: """
        Connects to Music Assistant and displays stream URLs as they arrive.
        Press Ctrl+C to stop monitoring.
        """
    )

    @Option(name: .long, help: "Music Assistant host")
    var host: String = "192.168.23.196"

    @Option(name: .long, help: "Music Assistant port")
    var port: Int = 8095

    @Flag(name: .long, help: "Test URL accessibility (default: true)")
    var test: Bool = true

    @Flag(name: .long, help: "Disable URL testing")
    var noTest: Bool = false

    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false

    @Flag(name: .long, help: "Verbose output (show all events)")
    var verbose: Bool = false

    mutating func run() async throws {
        let testURLs = test && !noTest
        let colorEnabled = !json && isatty(STDOUT_FILENO) != 0

        let formatter = OutputFormatter(jsonMode: json, colorEnabled: colorEnabled)

        if !json {
            print("🎵 Connecting to Music Assistant at \(host):\(port)...")
        }

        let client = MusicAssistantClient(host: host, port: port)
        try await client.connect()

        if !json {
            print("✓ Connected\n")
            print("Monitoring for BUILTIN_PLAYER events...")
            print("Press Ctrl+C to stop\n")
        }

        let monitor = StreamMonitor(client: client, testURLs: testURLs)

        for await streamInfo in monitor.streamEvents {
            let eventOutput = formatter.formatStreamEvent(streamInfo.event, streamURL: streamInfo.url)
            print(eventOutput, terminator: "")

            if let result = streamInfo.testResult {
                let testOutput = formatter.formatTestResult(result)
                print(testOutput)
            }
        }
    }
}
```

**Step 2: Test CLI manually**

```bash
swift run ma-stream --host 192.168.23.196 --port 8095
```

Expected: Connects and waits for events

**Step 3: Test with --no-test flag**

```bash
swift run ma-stream --host 192.168.23.196 --no-test
```

Expected: Shows URLs without testing them

**Step 4: Test JSON mode**

```bash
swift run ma-stream --host 192.168.23.196 --json
```

Expected: JSON output

**Step 5: Commit**

```bash
git add Sources/MAStream/main.swift
git commit -m "feat: add ma-stream CLI entry point

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: Documentation

**Files:**
- Create: `docs/cli/ma-stream.md`
- Modify: `README.md`

**Step 1: Write usage documentation**

Create `docs/cli/ma-stream.md`:

```markdown
# ma-stream - Stream URL Monitor

Monitor Music Assistant BUILTIN_PLAYER events and display streaming URLs.

## Usage

\`\`\`bash
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
\`\`\`

## Options

- `--host <host>` - Music Assistant host (default: 192.168.23.196)
- `--port <port>` - Port (default: 8095)
- `--test` - Test URL accessibility (default: enabled)
- `--no-test` - Disable URL testing
- `--json` - Output as JSON
- `--verbose` - Show all events (not just PLAY_MEDIA)

## Output Format

### Text Mode (default)

\`\`\`
🎵 Connected to Music Assistant at 192.168.23.196:8095

[12:34:56] PLAY_MEDIA event received
  Queue: player_builtin_12345
  Item:  67890

  Stream URL:
  http://192.168.23.196:8095/flow/session-abc/player_builtin_12345/67890.mp3

  Format: mp3
  Mode:   flow (gapless)
  Status: ✓ Accessible (200 OK)
\`\`\`

### JSON Mode

\`\`\`json
{
  "timestamp": "2025-10-16T12:34:56Z",
  "command": "PLAY_MEDIA",
  "stream_url": "http://192.168.23.196:8095/flow/session/queue/item.mp3",
  "queue_id": "queue",
  "queue_item_id": "item",
  "format": "mp3"
}
\`\`\`

## Examples

### Monitor and copy URLs to clipboard (macOS)

\`\`\`bash
ma-stream --json | jq -r '.stream_url' | pbcopy
\`\`\`

### Save URLs to file

\`\`\`bash
ma-stream --json >> stream-urls.jsonl
\`\`\`

### Test URLs with curl

\`\`\`bash
ma-stream --json | jq -r '.stream_url' | xargs curl -I
\`\`\`
```

**Step 2: Update README.md**

Add to CLI tools section:

```markdown
### ma-stream

Monitor BUILTIN_PLAYER events and display streaming URLs:

\`\`\`bash
ma-stream --host 192.168.23.196
\`\`\`

See [docs/cli/ma-stream.md](docs/cli/ma-stream.md) for full documentation.
```

**Step 3: Commit**

```bash
git add docs/cli/ma-stream.md README.md
git commit -m "docs: add ma-stream CLI documentation

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: Final Testing

**Files:**
- All files

**Step 1: Run full test suite**

```bash
swift test
```

Expected: All tests pass

**Step 2: Build release binary**

```bash
swift build -c release
```

Expected: Builds successfully

**Step 3: Test against live server**

```bash
.build/release/ma-stream --host 192.168.23.196 --port 8095
```

Start playback on Music Assistant and verify URLs appear

**Step 4: Test all CLI options**

```bash
# No testing
.build/release/ma-stream --no-test

# JSON mode
.build/release/ma-stream --json

# Help
.build/release/ma-stream --help
```

**Step 5: Run SwiftLint**

```bash
swiftlint
```

Expected: 0 violations

**Step 6: Run SwiftFormat**

```bash
swiftformat --lint .
```

Expected: Clean

**Step 7: Final commit if fixes needed**

```bash
git add .
git commit -m "fix: address linting issues

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Summary

This plan creates `ma-stream`, a focused CLI tool for monitoring Music Assistant streaming URLs with these features:

- Real-time BUILTIN_PLAYER event monitoring
- Stream URL display with formatting
- HTTP accessibility testing
- JSON mode for scripting
- Color-coded output
- Comprehensive test coverage

The tool follows the existing pattern of CLI utilities in the project and integrates cleanly with MusicAssistantKit.
