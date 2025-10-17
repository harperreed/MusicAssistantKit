// ABOUTME: Subcommand to set player volume level (0-100)
// ABOUTME: Validates range and sends volume command to MA server

import ArgumentParser
import Foundation
import MAPlayerLib

struct VolumeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "volume",
        abstract: "Set player volume (0-100)"
    )

    @Option(name: .long, help: "Music Assistant host")
    var host: String = "192.168.23.196"

    @Option(name: .long, help: "Music Assistant port")
    var port: Int = 8095

    @Option(name: .long, help: "Player ID")
    var player: String

    @Argument(help: "Volume level (0-100)")
    var level: Int

    mutating func run() async throws {
        let session = try await PlayerSession(
            host: host,
            port: port,
            playerId: player
        )

        try await session.setVolume(level)
        print("✓ Volume set to \(level)%")
    }
}
