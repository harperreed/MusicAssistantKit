// ABOUTME: Subcommand to start playback of tracks, albums, or playlists
// ABOUTME: Sends play command to MA server and waits for playback confirmation

import ArgumentParser
import Foundation
import MAPlayerLib

struct PlayCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "play",
        abstract: "Start playback of a track, album, or playlist"
    )

    @Option(name: .long, help: "Music Assistant host")
    var host: String = "192.168.23.196"

    @Option(name: .long, help: "Music Assistant port")
    var port: Int = 8095

    @Option(name: .long, help: "Player ID")
    var player: String

    @Argument(help: "URI to play (e.g., spotify:track:123)")
    var uri: String

    mutating func run() async throws {
        print("Connecting to \(host):\(port)...")

        let session = try await PlayerSession(
            host: host,
            port: port,
            playerId: player
        )

        print("Starting playback: \(uri)")
        try await session.startPlayback(uri: uri)

        print("✓ Playback started")
    }
}
