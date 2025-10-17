// ABOUTME: Subcommand for playback controls (next, previous, pause, resume, stop)
// ABOUTME: Executes single control action and exits

import ArgumentParser
import Foundation
import MAPlayerLib

struct ControlCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "control",
        abstract: "Control playback (next/prev/pause/resume/stop)"
    )

    enum Action: String, ExpressibleByArgument {
        case next
        case previous
        case pause
        case resume
        case stop
    }

    @Option(name: .long, help: "Music Assistant host")
    var host: String = "192.168.23.196"

    @Option(name: .long, help: "Music Assistant port")
    var port: Int = 8095

    @Option(name: .long, help: "Player ID")
    var player: String

    @Argument(help: "Control action")
    var action: Action

    mutating func run() async throws {
        let session = try await PlayerSession(
            host: host,
            port: port,
            playerId: player
        )

        switch action {
        case .next:
            try await session.next()
        case .previous:
            try await session.previous()
        case .pause:
            await session.pause()
        case .resume:
            await session.resume()
        case .stop:
            try await session.stop()
        }

        print("✓ \(action.rawValue)")
    }
}
