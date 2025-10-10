// ABOUTME: CLI tool for controlling Music Assistant players (play, pause, stop)
// ABOUTME: Usage: ma-control <player-id> <play|pause|stop>

import Foundation
import MusicAssistantKit

@main
struct MusicControl {
    static func main() async {
        // Parse arguments
        guard CommandLine.arguments.count >= 3 else {
            print("Usage: ma-control [--host HOST] [--port PORT] <player-id> <play|pause|stop>")
            print("Example: ma-control media_player.kitchen play")
            print("Example: ma-control --host 192.168.1.100 --port 8095 media_player.kitchen play")
            exit(1)
        }

        var host = "192.168.23.196"
        var port = 8095
        var args = Array(CommandLine.arguments[1...])

        // Parse optional --host and --port flags
        while args.count >= 2 {
            if args[0] == "--host" {
                host = args[1]
                args.removeFirst(2)
            } else if args[0] == "--port" {
                port = Int(args[1]) ?? 8095
                args.removeFirst(2)
            } else {
                break
            }
        }

        guard args.count >= 2 else {
            print("❌ Missing required arguments: <player-id> <play|pause|stop>")
            exit(1)
        }

        let playerId = args[0]
        let command = args[1].lowercased()

        guard ["play", "pause", "stop"].contains(command) else {
            print("❌ Invalid command. Use: play, pause, or stop")
            exit(1)
        }

        let client = MusicAssistantClient(host: host, port: port)

        do {
            print("🔌 Connecting to Music Assistant at \(host):\(port)...")
            try await client.connect()
            print("✅ Connected!")

            print("🎵 Sending \(command) command to \(playerId)...")

            switch command {
            case "play":
                try await client.play(playerId: playerId)
                print("▶️  Playing")
            case "pause":
                try await client.pause(playerId: playerId)
                print("⏸️  Paused")
            case "stop":
                try await client.stop(playerId: playerId)
                print("⏹️  Stopped")
            default:
                break
            }

            await client.disconnect()
            print("👋 Disconnected")

        } catch {
            print("❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }
}
