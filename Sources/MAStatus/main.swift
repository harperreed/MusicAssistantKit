// ABOUTME: CLI tool for displaying Music Assistant players and their current status
// ABOUTME: Usage: ma-status [--host HOST] [--port PORT]

import Foundation
import MusicAssistantKit

@main
struct MusicStatus {
    static func main() async {
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

        let client = MusicAssistantClient(host: host, port: port)

        do {
            print("🔌 Connecting to Music Assistant at \(host):\(port)...")
            try await client.connect()
            print("✅ Connected!\n")

            print("🎵 Fetching players...")
            let result = try await client.getPlayers()

            if let players = result?.value as? [[String: Any]] {
                print("📊 Found \(players.count) player(s):\n")
                print("─────────────────────────────────────────")

                for (index, player) in players.enumerated() {
                    let playerId = player["player_id"] as? String ?? "unknown"
                    let name = player["name"] as? String ?? "Unknown"
                    let type = player["type"] as? String ?? "unknown"
                    let provider = player["provider"] as? String ?? "unknown"
                    let available = player["available"] as? Bool ?? false
                    let powered = player["powered"] as? Bool ?? false

                    // Get state if available
                    var state = "unknown"
                    var volume: Int?
                    if let stateStr = player["state"] as? String {
                        state = stateStr
                    }
                    if let volumeLevel = player["volume_level"] as? Int {
                        volume = volumeLevel
                    }

                    print("\n[\(index + 1)] \(name)")
                    print("  ID: \(playerId)")
                    print("  Type: \(type)")
                    print("  Provider: \(provider)")

                    // Status indicators
                    let availableEmoji = available ? "✅" : "❌"
                    let poweredEmoji = powered ? "🔋" : "⚫️"
                    print("  Available: \(availableEmoji) \(available ? "Yes" : "No")")
                    print("  Powered: \(poweredEmoji) \(powered ? "Yes" : "No")")

                    // Playback state
                    let stateEmoji = stateEmoji(state)
                    print("  State: \(stateEmoji) \(state)")

                    if let vol = volume {
                        print("  Volume: 🔊 \(vol)%")
                    }

                    // Now playing info if available
                    if let currentItem = player["current_item"] as? [String: Any],
                       let itemName = currentItem["name"] as? String
                    {
                        print("  Now Playing: 🎶 \(itemName)")

                        if let artists = currentItem["artists"] as? [[String: Any]] {
                            let artistNames = artists.compactMap { $0["name"] as? String }.joined(separator: ", ")
                            if !artistNames.isEmpty {
                                print("  Artist: 🎤 \(artistNames)")
                            }
                        }
                    }
                }

                print("\n─────────────────────────────────────────")
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
