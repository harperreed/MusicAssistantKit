// ABOUTME: Subcommand to display current playback status and player information
// ABOUTME: Shows track, position, volume, queue size in human-readable format

import ArgumentParser
import Foundation
import MAPlayerLib

struct InfoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show current playback status"
    )

    @Option(name: .long, help: "Music Assistant host")
    var host: String = "192.168.23.196"

    @Option(name: .long, help: "Music Assistant port")
    var port: Int = 8095

    @Option(name: .long, help: "Player ID")
    var player: String

    mutating func run() async throws {
        let session = try await PlayerSession(
            host: host,
            port: port,
            playerId: player
        )

        let info = try await session.getPlaybackInfo()

        print("Player: \(player)")
        print("State: \(info.playerState)")

        if let track = info.currentTrack {
            print("Track: \(track)")
        }

        if let position = info.position, let duration = info.duration {
            let posStr = formatTime(position)
            let durStr = formatTime(duration)
            print("Position: \(posStr) / \(durStr)")
        }

        if let volume = info.volume {
            print("Volume: \(volume)%")
        }

        if let queueSize = info.queueSize {
            print("Queue: \(queueSize) items")
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
