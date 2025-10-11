// ABOUTME: CLI tool for displaying Music Assistant players and their current status
// ABOUTME: Usage: ma-status [--host HOST] [--port PORT]

import Foundation
import MusicAssistantKit

@main
struct MusicStatus {
    struct Arguments {
        let host: String
        let port: Int

        static func parse() -> Arguments {
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

            return Arguments(host: host, port: port)
        }
    }

    static func main() async {
        let args = Arguments.parse()
        let client = MusicAssistantClient(host: args.host, port: args.port)

        do {
            print("🔌 Connecting to Music Assistant at \(args.host):\(args.port)...")
            try await client.connect()
            print("✅ Connected!\n")

            print("🎵 Fetching players...")
            let result = try await client.getPlayers()

            if let players = result?.value as? [[String: Any]] {
                displayPlayers(players)
            } else {
                print("No players found.")
            }

            await client.disconnect()
            print("\n👋 Disconnected")
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }

    static func displayPlayers(_ players: [[String: Any]]) {
        print("📊 Found \(players.count) player(s):\n")
        print("─────────────────────────────────────────")

        for (index, player) in players.enumerated() {
            displayPlayer(player, index: index)
        }

        print("\n─────────────────────────────────────────")
    }

    static func displayPlayer(_ player: [String: Any], index: Int) {
        let playerId = player["player_id"] as? String ?? "unknown"
        let name = player["name"] as? String ?? "Unknown"
        let type = player["type"] as? String ?? "unknown"
        let provider = player["provider"] as? String ?? "unknown"
        let available = player["available"] as? Bool ?? false
        let powered = player["powered"] as? Bool ?? false

        print("\n[\(index + 1)] \(name)")
        print("  ID: \(playerId)")
        print("  Type: \(type)")
        print("  Provider: \(provider)")

        displayPlayerStatus(available: available, powered: powered)
        displayPlaybackState(player)
        displayNowPlaying(player)
    }

    static func displayPlayerStatus(available: Bool, powered: Bool) {
        let availableEmoji = available ? "✅" : "❌"
        let poweredEmoji = powered ? "🔋" : "⚫️"
        print("  Available: \(availableEmoji) \(available ? "Yes" : "No")")
        print("  Powered: \(poweredEmoji) \(powered ? "Yes" : "No")")
    }

    static func displayPlaybackState(_ player: [String: Any]) {
        let state = player["state"] as? String ?? "unknown"
        let stateEmoji = stateEmoji(state)
        print("  State: \(stateEmoji) \(state)")

        if let volume = player["volume_level"] as? Int {
            print("  Volume: 🔊 \(volume)%")
        }
    }

    static func displayNowPlaying(_ player: [String: Any]) {
        guard let currentItem = player["current_item"] as? [String: Any],
              let itemName = currentItem["name"] as? String
        else {
            return
        }

        print("  Now Playing: 🎶 \(itemName)")

        if let artists = currentItem["artists"] as? [[String: Any]] {
            let artistNames = artists.compactMap { $0["name"] as? String }.joined(separator: ", ")
            if !artistNames.isEmpty {
                print("  Artist: 🎤 \(artistNames)")
            }
        }
    }

    static func stateEmoji(_ state: String) -> String {
        switch state.lowercased() {
        case "playing": "▶️"
        case "paused": "⏸️"
        case "idle": "⏹️"
        case "off": "🔴"
        default: "❓"
        }
    }
}
