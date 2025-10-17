import ArgumentParser
import Foundation
import MAStreamLib
import MusicAssistantKit

// ABOUTME: CLI entry point for ma-stream tool
// ABOUTME: Monitors BUILTIN_PLAYER events and displays stream URLs
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

    @Flag(name: .long, help: "Disable URL testing")
    var noTest: Bool = false

    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false

    @Flag(name: .long, help: "Verbose output (show all events)")
    var verbose: Bool = false

    mutating func run() async throws {
        let testURLs = !noTest
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
