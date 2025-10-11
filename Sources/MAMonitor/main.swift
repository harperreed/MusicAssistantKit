// ABOUTME: CLI tool for monitoring Music Assistant player events in real-time
// ABOUTME: Usage: ma-monitor [player-id]

import Combine
import Foundation
import MusicAssistantKit

@main
struct MusicMonitor {
    struct Arguments {
        let host: String
        let port: Int
        let filterPlayerId: String?

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

            let filterPlayerId = args.isEmpty ? nil : args[0]
            return Arguments(host: host, port: port, filterPlayerId: filterPlayerId)
        }
    }

    static func main() async {
        let args = Arguments.parse()
        let client = MusicAssistantClient(host: args.host, port: args.port)
        var cancellables = Set<AnyCancellable>()

        do {
            print("🔌 Connecting to Music Assistant at \(args.host):\(args.port)...")
            try await client.connect()
            print("✅ Connected!")

            printMonitoringInfo(filterPlayerId: args.filterPlayerId)

            subscribeToEvents(client: client, filterPlayerId: args.filterPlayerId, cancellables: &cancellables)

            try await Task.sleep(nanoseconds: 3_600_000_000_000) // 1 hour max
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }

    static func printMonitoringInfo(filterPlayerId: String?) {
        if let playerId = filterPlayerId {
            print("👀 Monitoring player: \(playerId)")
        } else {
            print("👀 Monitoring all players")
        }
        print("Press Ctrl+C to exit\n")
        print("─────────────────────────────────────────")
    }

    static func subscribeToEvents(
        client: MusicAssistantClient,
        filterPlayerId: String?,
        cancellables: inout Set<AnyCancellable>
    ) {
        subscribeToPlayerUpdates(client: client, filterPlayerId: filterPlayerId, cancellables: &cancellables)
        subscribeToQueueUpdates(client: client, filterPlayerId: filterPlayerId, cancellables: &cancellables)
    }

    static func subscribeToPlayerUpdates(
        client: MusicAssistantClient,
        filterPlayerId: String?,
        cancellables: inout Set<AnyCancellable>
    ) {
        Task {
            await client.events.playerUpdates
                .sink { event in
                    if let filter = filterPlayerId, event.playerId != filter {
                        return
                    }
                    handlePlayerUpdate(event)
                }
                .store(in: &cancellables)
        }
    }

    static func subscribeToQueueUpdates(
        client: MusicAssistantClient,
        filterPlayerId: String?,
        cancellables: inout Set<AnyCancellable>
    ) {
        Task {
            await client.events.queueUpdates
                .sink { event in
                    if let filter = filterPlayerId, event.queueId != filter {
                        return
                    }
                    handleQueueUpdate(event)
                }
                .store(in: &cancellables)
        }
    }

    static func handlePlayerUpdate(_ event: PlayerUpdateEvent) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("\n[\(timestamp)] 🎵 Player Update: \(event.playerId)")

        if let state = event.data["state"]?.value as? String {
            let emoji = stateEmoji(state)
            print("  State: \(emoji) \(state)")
        }
        if let volume = event.data["volume_level"]?.value as? Int {
            print("  Volume: 🔊 \(volume)%")
        }
        if let elapsed = event.data["elapsed_time"]?.value as? Double {
            let minutes = Int(elapsed) / 60
            let seconds = Int(elapsed) % 60
            print("  Elapsed: ⏱️  \(minutes):\(String(format: "%02d", seconds))")
        }
        if let currentItem = event.data["current_item"]?.value as? [String: Any],
           let name = currentItem["name"] as? String {
            print("  Now Playing: 🎶 \(name)")
        }
        print("─────────────────────────────────────────")
    }

    static func handleQueueUpdate(_ event: QueueUpdateEvent) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("\n[\(timestamp)] 📋 Queue Update: \(event.queueId)")

        if let items = event.data["items"]?.value as? Int {
            print("  Items in queue: \(items)")
        }
        if let shuffleEnabled = event.data["shuffle_enabled"]?.value as? Bool {
            print("  Shuffle: \(shuffleEnabled ? "🔀 On" : "➡️  Off")")
        }
        if let repeatMode = event.data["repeat_mode"]?.value as? String {
            let emoji = repeatMode == "all" ? "🔁" : repeatMode == "one" ? "🔂" : "➡️"
            print("  Repeat: \(emoji) \(repeatMode)")
        }
        print("─────────────────────────────────────────")
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
