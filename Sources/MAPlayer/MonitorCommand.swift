// ABOUTME: Subcommand to monitor BUILTIN_PLAYER events and display stream URLs
// ABOUTME: Supports text and JSON output formats, reuses MAStreamLib formatters

import ArgumentParser
import Foundation
import MAPlayerLib
import MAStreamLib

struct MonitorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "monitor",
        abstract: "Monitor playback events and stream URLs"
    )

    @Option(name: .long, help: "Music Assistant host")
    var host: String = "192.168.23.196"

    @Option(name: .long, help: "Music Assistant port")
    var port: Int = 8095

    @Option(name: .long, help: "Player ID")
    var player: String

    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false

    @Flag(name: .long, help: "Test URL accessibility")
    var testUrls: Bool = false

    mutating func run() async throws {
        print("Monitoring events for player: \(player)")

        let session = try await PlayerSession(
            host: host,
            port: port,
            playerId: player
        )

        let formatter = OutputFormatter(jsonMode: json, colorEnabled: !json)
        let tester = testUrls ? URLTester() : nil

        for await streamInfo in session.streamEvents {
            var testResult: TestResult?

            if let tester,
               let urlString = streamInfo.streamURL,
               let url = URL(string: urlString) {
                testResult = await tester.test(url: url)
            }

            let output = formatter.formatStreamEvent(
                streamInfo.event,
                streamURL: streamInfo.streamURL ?? "N/A"
            )

            print(output)

            if let result = testResult, !json {
                let resultOutput = formatter.formatTestResult(result)
                print(resultOutput)
            }
        }
    }
}
