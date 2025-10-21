// ABOUTME: Example CLI demonstrating Music Assistant streaming player functionality
// ABOUTME: Shows how to register a built-in player, handle events, and stream audio

import Foundation
import MusicAssistantKit

#if os(macOS) || os(iOS)
    @available(macOS 12.0, iOS 15.0, *)
    @main
    struct MAPlayer {
        static func main() async throws {
            let host = ProcessInfo.processInfo.environment["MA_HOST"] ?? "localhost"
            let port = Int(ProcessInfo.processInfo.environment["MA_PORT"] ?? "8095") ?? 8095

            print("Music Assistant Streaming Player Demo")
            print("======================================")
            print("Connecting to \(host):\(port)...")

            let client = MusicAssistantClient(host: host, port: port)
            try await client.connect()

            print("✓ Connected to Music Assistant")

            // Create and register streaming player
            let player = StreamingPlayer(client: client, playerName: "MusicAssistantKit Demo")

            print("Registering built-in player...")
            try await player.register()

            if let playerId = await player.currentPlayerId {
                print("✓ Registered as player: \(playerId)")
                print("\nPlayer is now ready to receive commands from Music Assistant.")
                print("You can control it from the Music Assistant web interface.")
                print("\nPress Ctrl+C to stop and unregister.\n")

                // Keep running until interrupted
                try await withTaskCancellationHandler {
                    try await Task.sleep(for: .seconds(3600))  // 1 hour
                } onCancel: {
                    Task {
                        print("\nShutting down...")
                        try? await player.unregister()
                        await client.disconnect()
                        print("✓ Player unregistered and disconnected")
                    }
                }
            } else {
                print("✗ Failed to get player ID")
            }

            await client.disconnect()
        }
    }
#else
    @main
    struct MAPlayer {
        static func main() {
            print("Streaming player is only available on macOS and iOS")
        }
    }
#endif
