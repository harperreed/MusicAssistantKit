#!/usr/bin/env swift

// ABOUTME: CLI tool for monitoring Music Assistant player events in real-time
// ABOUTME: Usage: swift ma-monitor.swift [player-id]

import Foundation
import Combine

#if canImport(MusicAssistantKit)
import MusicAssistantKit
#else
print("⚠️  MusicAssistantKit not found. Run from package root or add to swift include path.")
exit(1)
#endif

let host = "192.168.23.196"
let port = 8095

// Parse arguments
let filterPlayerId = CommandLine.arguments.count >= 2 ? CommandLine.arguments[1] : nil

@main
struct MusicMonitor {
    static func main() async {
        let client = MusicAssistantClient(host: host, port: port)
        var cancellables = Set<AnyCancellable>()

        do {
            print("🔌 Connecting to Music Assistant at \(host):\(port)...")
            try await client.connect()
            print("✅ Connected!")

            if let playerId = filterPlayerId {
                print("👀 Monitoring player: \(playerId)")
            } else {
                print("👀 Monitoring all players")
            }
            print("Press Ctrl+C to exit\n")
            print("─────────────────────────────────────────")

            // Subscribe to player updates
            await client.events.playerUpdates
                .sink { event in
                    // Filter by player ID if specified
                    if let filter = filterPlayerId, event.playerId != filter {
                        return
                    }

                    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                    print("\n[\(timestamp)] 🎵 Player Update: \(event.playerId)")

                    // Parse and display event data
                    if let state = event.data["state"] as? String {
                        let emoji = stateEmoji(state)
                        print("  State: \(emoji) \(state)")
                    }
                    if let volume = event.data["volume_level"] as? Int {
                        print("  Volume: 🔊 \(volume)%")
                    }
                    if let elapsed = event.data["elapsed_time"] as? Double {
                        let minutes = Int(elapsed) / 60
                        let seconds = Int(elapsed) % 60
                        print("  Elapsed: ⏱️  \(minutes):\(String(format: "%02d", seconds))")
                    }
                    if let currentItem = event.data["current_item"] as? [String: Any],
                       let name = currentItem["name"] as? String {
                        print("  Now Playing: 🎶 \(name)")
                    }
                    print("─────────────────────────────────────────")
                }
                .store(in: &cancellables)

            // Subscribe to queue updates
            await client.events.queueUpdates
                .sink { event in
                    // Filter by queue ID if specified (queue ID usually matches player ID)
                    if let filter = filterPlayerId, event.queueId != filter {
                        return
                    }

                    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                    print("\n[\(timestamp)] 📋 Queue Update: \(event.queueId)")

                    if let items = event.data["items"] as? Int {
                        print("  Items in queue: \(items)")
                    }
                    if let shuffleEnabled = event.data["shuffle_enabled"] as? Bool {
                        print("  Shuffle: \(shuffleEnabled ? "🔀 On" : "➡️  Off")")
                    }
                    if let repeatMode = event.data["repeat_mode"] as? String {
                        let emoji = repeatMode == "all" ? "🔁" : repeatMode == "one" ? "🔂" : "➡️"
                        print("  Repeat: \(emoji) \(repeatMode)")
                    }
                    print("─────────────────────────────────────────")
                }
                .store(in: &cancellables)

            // Keep running until interrupted
            try await Task.sleep(for: .seconds(3600)) // 1 hour max

        } catch {
            print("❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }

    static func stateEmoji(_ state: String) -> String {
        switch state.lowercased() {
        case "playing": return "▶️"
        case "paused": return "⏸️"
        case "idle": return "⏹️"
        case "off": return "🔴"
        default: return "❓"
        }
    }
}
