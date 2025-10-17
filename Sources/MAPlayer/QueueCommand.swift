// ABOUTME: Subcommand for queue operations (list, clear)
// ABOUTME: Displays queue contents or performs queue management actions

import ArgumentParser
import Foundation
import MAPlayerLib
import MusicAssistantKit

struct QueueCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "queue",
        abstract: "Manage playback queue"
    )

    enum Action: String, ExpressibleByArgument {
        case list
        case clear
    }

    @Option(name: .long, help: "Music Assistant host")
    var host: String = "192.168.23.196"

    @Option(name: .long, help: "Music Assistant port")
    var port: Int = 8095

    @Option(name: .long, help: "Player ID (queue ID)")
    var player: String

    @Argument(help: "Queue action")
    var action: Action

    mutating func run() async throws {
        let session = try await PlayerSession(
            host: host,
            port: port,
            playerId: player
        )

        switch action {
        case .list:
            let queueData = try await session.getQueue()

            if let queueData {
                let items = parseQueueItems(from: queueData)
                print("Queue: \(items.count) items")
                for (index, item) in items.enumerated() {
                    print("  \(index + 1). \(item)")
                }
            } else {
                print("Queue: 0 items")
            }

        case .clear:
            try await session.clearQueue()
            print("✓ Queue cleared")
        }
    }

    private func parseQueueItems(from data: AnyCodable) -> [String] {
        var items: [String] = []

        if let dict = data.value as? [String: Any],
           let itemsArray = dict["items"] as? [[String: Any]] {
            for item in itemsArray {
                if let name = item["name"] as? String {
                    items.append(name)
                } else if let title = item["title"] as? String {
                    items.append(title)
                } else {
                    items.append("Unknown")
                }
            }
        }

        return items
    }
}
