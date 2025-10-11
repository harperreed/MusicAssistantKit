// ABOUTME: CLI tool for controlling Music Assistant players (play, pause, stop)
// ABOUTME: Usage: ma-control <player-id> <play|pause|stop>

import Foundation
import MusicAssistantKit

@main
struct MusicControl {
    struct Arguments {
        let host: String
        let port: Int
        let playerId: String
        let command: String

        static func parse() -> Arguments? {
            guard CommandLine.arguments.count >= 3 else {
                printUsage()
                return nil
            }

            var host = "192.168.23.196"
            var port = 8095
            var args = Array(CommandLine.arguments[1...])

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
                return nil
            }

            let playerId = args[0]
            let command = args[1].lowercased()

            guard ["play", "pause", "stop"].contains(command) else {
                print("❌ Invalid command. Use: play, pause, or stop")
                return nil
            }

            return Arguments(host: host, port: port, playerId: playerId, command: command)
        }

        static func printUsage() {
            print("Usage: ma-control [--host HOST] [--port PORT] <player-id> <play|pause|stop>")
            print("Example: ma-control media_player.kitchen play")
            print("Example: ma-control --host 192.168.1.100 --port 8095 media_player.kitchen play")
        }
    }

    static func main() async {
        guard let args = Arguments.parse() else {
            exit(1)
        }

        await executeCommand(args)
    }

    static func executeCommand(_ args: Arguments) async {
        let client = MusicAssistantClient(host: args.host, port: args.port)

        do {
            print("🔌 Connecting to Music Assistant at \(args.host):\(args.port)...")
            try await client.connect()
            print("✅ Connected!")

            print("🎵 Sending \(args.command) command to \(args.playerId)...")
            try await performPlayerCommand(client: client, playerId: args.playerId, command: args.command)

            await client.disconnect()
            print("👋 Disconnected")
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }

    static func performPlayerCommand(client: MusicAssistantClient, playerId: String, command: String) async throws {
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
    }
}
