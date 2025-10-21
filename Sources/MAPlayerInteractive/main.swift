// ABOUTME: Interactive CLI player for testing Music Assistant streaming functionality
// ABOUTME: Minimal mpv-style interface with keyboard controls for playback testing

import Combine
import Foundation
import MusicAssistantKit

#if os(macOS) || os(iOS)
    @available(macOS 12.0, iOS 15.0, *)
    @main
    struct MAPlayerInteractive {
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
                var signalSource: DispatchSourceSignal?
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
                    sigintSrc.setEventHandler {
                        continuation.resume()
                    }
                    sigintSrc.resume()
                    signal(SIGINT, SIG_IGN)
                    signalSource = sigintSrc  // Keep alive
                }

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

        static func subscribeToEvents(client: MusicAssistantClient, playerId: String) async {
            var cancellables = Set<AnyCancellable>()
            var lastState: String?

            await client.events.builtinPlayerEvents
                .sink { eventPlayerId, event in
                    guard eventPlayerId == playerId else { return }
                    displayEvent(event)
                }
                .store(in: &cancellables)

            await client.events.rawEvents
                .sink { event in
                    if event.event == "builtin_player",
                       event.objectId == playerId,
                       let data = event.data?.value as? [String: Any],
                       let type = data["type"] as? String {

                        let stateIndicator: String
                        switch type {
                        case "PLAY":
                            stateIndicator = "▶️  PLAYING"
                        case "PAUSE":
                            stateIndicator = "⏸️  PAUSED"
                        case "STOP":
                            stateIndicator = "⏹️  STOPPED"
                        case "PLAY_MEDIA":
                            if let mediaUrl = data["media_url"] as? String {
                                stateIndicator = "🎶 STREAMING: \(mediaUrl)"
                            } else {
                                stateIndicator = "🎶 STREAMING"
                            }
                        case "SET_VOLUME":
                            if let volume = data["volume"] as? Double {
                                stateIndicator = "🔊 VOLUME: \(Int(volume))%"
                            } else {
                                stateIndicator = "🔊 VOLUME"
                            }
                        case "MUTE":
                            stateIndicator = "🔇 MUTED"
                        case "UNMUTE":
                            stateIndicator = "🔊 UNMUTED"
                        case "POWER_ON":
                            stateIndicator = "⚡ POWER ON"
                        case "POWER_OFF":
                            stateIndicator = "💤 POWER OFF"
                        default:
                            stateIndicator = "📡 \(type)"
                        }

                        if stateIndicator != lastState {
                            let timestamp = DateFormatter.localizedString(
                                from: Date(),
                                dateStyle: .none,
                                timeStyle: .medium
                            )
                            print("[\(timestamp)] \(stateIndicator)")
                            lastState = stateIndicator
                        }
                    }
                }
                .store(in: &cancellables)

            // Keep cancellables alive by storing in a global
            _ = cancellables
        }

        static func displayEvent(_ event: BuiltinPlayerEvent) {
            let timestamp = DateFormatter.localizedString(
                from: Date(),
                dateStyle: .none,
                timeStyle: .medium
            )

            switch event.type {
            case .play:
                print("[\(timestamp)] ▶️  PLAY command received")
            case .pause:
                print("[\(timestamp)] ⏸️  PAUSE command received")
            case .stop:
                print("[\(timestamp)] ⏹️  STOP command received")
            case .playMedia:
                if let url = event.mediaUrl {
                    print("[\(timestamp)] 🎶 PLAY_MEDIA: \(url)")
                } else {
                    print("[\(timestamp)] 🎶 PLAY_MEDIA command received")
                }
            case .setVolume:
                if let vol = event.volume {
                    print("[\(timestamp)] 🔊 SET_VOLUME: \(Int(vol))%")
                } else {
                    print("[\(timestamp)] 🔊 SET_VOLUME command received")
                }
            case .mute:
                print("[\(timestamp)] 🔇 MUTE command received")
            case .unmute:
                print("[\(timestamp)] 🔊 UNMUTE command received")
            case .powerOn:
                print("[\(timestamp)] ⚡ POWER_ON command received")
            case .powerOff:
                print("[\(timestamp)] 💤 POWER_OFF command received")
            case .timeout:
                print("[\(timestamp)] ⏱️  Player timed out (no state update)")
            }
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
