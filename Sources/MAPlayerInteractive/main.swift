// ABOUTME: Interactive CLI player for testing Music Assistant streaming functionality
// ABOUTME: Minimal mpv-style interface with keyboard controls for playback testing

import Combine
import Foundation
import MusicAssistantKit

#if os(macOS) || os(iOS)
    @available(macOS 12.0, iOS 15.0, *)
    @main
    struct MAPlayerInteractive {
        // Keep cancellables alive for the duration of the program
        @MainActor
        static var globalCancellables = Set<AnyCancellable>()

        static func main() async throws {
            let host = ProcessInfo.processInfo.environment["MA_HOST"] ?? "localhost"
            let port = Int(ProcessInfo.processInfo.environment["MA_PORT"] ?? "8095") ?? 8095

            print("╔════════════════════════════════════════════════╗")
            print("║   Music Assistant Interactive Player          ║")
            print("║   Minimal mpv-style streaming test app        ║")
            print("╚════════════════════════════════════════════════╝")
            print("")
            print("📡 Connecting to \(host):\(port)...")

            let client = MusicAssistantClient(host: host, port: port)
            try await client.connect()

            print("✓ Connected to Music Assistant")
            print("")

            // Create and register streaming player
            let playerName = "MusicAssistantKit Interactive [\(ProcessInfo.processInfo.processIdentifier)]"
            let player = StreamingPlayer(client: client, playerName: playerName)

            print("🎵 Registering player: \(playerName)")
            try await player.register()

            if let playerId = await player.currentPlayerId {
                print("✓ Registered as player ID: \(playerId)")
                print("")
                print("╔════════════════════════════════════════════════╗")
                print("║              READY TO STREAM                   ║")
                print("╠════════════════════════════════════════════════╣")
                print("║                                                ║")
                print("║  Control this player from Music Assistant      ║")
                print("║  web interface at http://\(host):\(port)/")
                print("║                                                ║")
                print("║  The player will show up as:                   ║")
                print("║  \"\(playerName)\"")
                print("║                                                ║")
                print("╠════════════════════════════════════════════════╣")
                print("║  Status will be displayed here in real-time    ║")
                print("╚════════════════════════════════════════════════╝")
                print("")

                // Subscribe to player events for status display
                await subscribeToEvents(client: client, playerId: playerId)

                print("💡 TIP: Queue some music in Music Assistant and play it!")
                print("💡 You should see status updates appear here as you control playback")
                print("")
                print("Press Ctrl+C to stop and unregister")
                print("")
                print("─────────────────────────────────────────────────")
                print("")

                // Set up signal handling and wait for Ctrl+C
                let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)

                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    sigintSrc.setEventHandler {
                        continuation.resume()
                    }
                    sigintSrc.resume()
                    signal(SIGINT, SIG_IGN)
                }

                // Signal source stays alive until here
                sigintSrc.cancel()

                // Cleanup
                print("")
                print("─────────────────────────────────────────────────")
                print("")
                print("🛑 Shutting down...")
                try? await player.unregister()
                await client.disconnect()
                print("✓ Player unregistered and disconnected")
                print("👋 Goodbye!")
            } else {
                print("✗ Failed to get player ID")
                await client.disconnect()
            }
        }

        @MainActor
        static func subscribeToEvents(client: MusicAssistantClient, playerId: String) async {
            // Get host/port for URL construction
            let host = await client.host
            let port = await client.port

            // Subscribe to raw events to get detailed information
            await client.events.rawEvents
                .sink { event in
                    Task { @MainActor in
                        if event.event == "builtin_player",
                           event.objectId == playerId,
                           let data = event.data?.value as? [String: Any],
                           let type = data["type"] as? String {

                            let stateIndicator = switch type {
                            case "PLAY":
                                "▶️ PLAYING"
                            case "PAUSE":
                                "⏸️ PAUSED"
                            case "STOP":
                                "⏹️ STOPPED"
                            case "PLAY_MEDIA":
                                (data["media_url"] as? String).map { mediaUrl in
                                    let fullUrl = "http://\(host):\(port)/\(mediaUrl)"
                                    return "🎶 STREAMING:\n   URL: \(fullUrl)\n   Path: \(mediaUrl)"
                                } ?? "🎶 STREAMING"
                            case "SET_VOLUME":
                                (data["volume"] as? Double).map { volume in
                                    "🔊 VOLUME: \(Int(volume))%"
                                } ?? "🔊 VOLUME"
                            case "MUTE":
                                "🔇 MUTED"
                            case "UNMUTE":
                                "🔊 UNMUTED"
                            case "POWER_ON":
                                "⚡ POWER ON"
                            case "POWER_OFF":
                                "💤 POWER OFF"
                            default:
                                "📡 \(type)"
                            }

                            let timestamp = DateFormatter.localizedString(
                                from: Date(),
                                dateStyle: .none,
                                timeStyle: .medium
                            )
                            print("[\(timestamp)] \(stateIndicator)")
                        }
                    }
                }
                .store(in: &globalCancellables)
        }
    }
#else
    @main
    struct MAPlayerInteractive {
        static func main() {
            print("Interactive streaming player is only available on macOS and iOS")
        }
    }
#endif
