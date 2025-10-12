// ABOUTME: CLI tool for controlling Music Assistant players and queues
// ABOUTME: Usage: ma-control <player-id> <command> [args...]

import Foundation
import MusicAssistantKit

@main
struct MusicControl {
    enum Command {
        case play(playerId: String)
        case pause(playerId: String)
        case stop(playerId: String)
        case seek(queueId: String, position: Double)
        case group(playerId: String, targetPlayer: String)
        case ungroup(playerId: String)
    }

    struct Arguments {
        let host: String
        let port: Int
        let command: Command

        static func parse() -> Arguments? {
            guard CommandLine.arguments.count >= 3 else {
                printUsage()
                return nil
            }

            var args = Array(CommandLine.arguments[1...])
            let (host, port) = parseConnectionOptions(&args)

            guard args.count >= 2 else {
                print("❌ Missing required arguments")
                printUsage()
                return nil
            }

            guard let command = parseCommand(args) else {
                return nil
            }

            return Arguments(host: host, port: port, command: command)
        }

        static func parseConnectionOptions(_ args: inout [String]) -> (String, Int) {
            var host = "192.168.23.196"
            var port = 8095

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

            return (host, port)
        }

        static func parseCommand(_ args: [String]) -> Command? {
            let id = args[0]
            let commandStr = args[1].lowercased()

            switch commandStr {
            case "play":
                return .play(playerId: id)
            case "pause":
                return .pause(playerId: id)
            case "stop":
                return .stop(playerId: id)
            case "seek":
                guard args.count >= 3, let position = Double(args[2]) else {
                    print("❌ seek requires a position in seconds")
                    return nil
                }
                return .seek(queueId: id, position: position)
            case "group":
                guard args.count >= 3 else {
                    print("❌ group requires a target player ID")
                    return nil
                }
                return .group(playerId: id, targetPlayer: args[2])
            case "ungroup":
                return .ungroup(playerId: id)
            default:
                print("❌ Invalid command: \(commandStr)")
                printUsage()
                return nil
            }
        }

        static func printUsage() {
            print("Usage: ma-control [--host HOST] [--port PORT] <id> <command> [args...]")
            print("")
            print("Player Commands:")
            print("  ma-control <player-id> play")
            print("  ma-control <player-id> pause")
            print("  ma-control <player-id> stop")
            print("  ma-control <player-id> group <target-player-id>")
            print("  ma-control <player-id> ungroup")
            print("")
            print("Queue Commands:")
            print("  ma-control <queue-id> seek <position-seconds>")
            print("")
            print("Examples:")
            print("  ma-control media_player.kitchen play")
            print("  ma-control media_player.kitchen seek 42.5")
            print("  ma-control media_player.kitchen group media_player.bedroom")
            print("  ma-control media_player.kitchen ungroup")
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

            try await performCommand(client: client, command: args.command)

            await client.disconnect()
            print("👋 Disconnected")
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }

    static func performCommand(client: MusicAssistantClient, command: Command) async throws {
        switch command {
        case let .play(playerId):
            print("🎵 Playing \(playerId)...")
            try await client.play(playerId: playerId)
            print("▶️  Playing")
        case let .pause(playerId):
            print("🎵 Pausing \(playerId)...")
            try await client.pause(playerId: playerId)
            print("⏸️  Paused")
        case let .stop(playerId):
            print("🎵 Stopping \(playerId)...")
            try await client.stop(playerId: playerId)
            print("⏹️  Stopped")
        case let .seek(queueId, position):
            print("🎵 Seeking \(queueId) to \(position)s...")
            try await client.seek(queueId: queueId, position: position)
            print("⏩ Seeked to \(position)s")
        case let .group(playerId, targetPlayer):
            print("🎵 Grouping \(playerId) with \(targetPlayer)...")
            try await client.group(playerId: playerId, targetPlayer: targetPlayer)
            print("🔗 Grouped")
        case let .ungroup(playerId):
            print("🎵 Ungrouping \(playerId)...")
            try await client.ungroup(playerId: playerId)
            print("🔓 Ungrouped")
        }
    }
}
