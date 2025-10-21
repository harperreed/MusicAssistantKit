// ABOUTME: Simple CLI tool to play a URL through Music Assistant built-in player
// ABOUTME: Usage: swift run ma-player-play <url> [--duration SECONDS]

import Foundation
import MusicAssistantKit

enum MAPlayerError: Error {
    case timeout
}

#if os(macOS) || os(iOS)
    @available(macOS 12.0, iOS 15.0, *)
    @main
    struct MAPlayerPlay {
        static func main() async throws {
            let args = CommandLine.arguments
            guard args.count >= 2 else {
                printUsage()
                exit(1)
            }

            let url = args[1]
            var duration: TimeInterval = 30.0  // Default: play for 30 seconds

            // Parse optional --duration flag
            if args.count >= 4 && args[2] == "--duration" {
                if let d = TimeInterval(args[3]) {
                    duration = d
                }
            }

            let host = ProcessInfo.processInfo.environment["MA_HOST"] ?? "localhost"
            let port = Int(ProcessInfo.processInfo.environment["MA_PORT"] ?? "8095") ?? 8095

            print("🎵 Music Assistant URL Player")
            print("=" * 50)
            print("Server: \(host):\(port)")
            print("URL: \(url)")
            print("Duration: \(Int(duration))s")
            print("")

            // Connect to Music Assistant
            print("📡 Connecting...")
            let client = MusicAssistantClient(host: host, port: port)
            try await client.connect()
            print("✓ Connected")

            // Create and register player
            let playerName = "URL Player [\(ProcessInfo.processInfo.processIdentifier)]"
            let player = StreamingPlayer(client: client, playerName: playerName)

            print("🎵 Registering player...")
            try await player.register()

            guard let playerId = await player.currentPlayerId else {
                print("✗ Failed to get player ID")
                await client.disconnect()
                exit(1)
            }

            print("✓ Registered as: \(playerId)")
            print("")

            // Try to play the URL via Music Assistant
            print("▶️  Attempting to play URL...")
            print("   Note: This requires the URL to be a valid music source")
            print("   that Music Assistant can recognize and stream.")
            print("")

            do {
                // Try to play the URL
                // For built-in players, the queue ID is the same as the player ID
                print("   Queueing media to player...")
                print("")

                let result = try await withThrowingTaskGroup(of: (Bool, AnyCodable?).self) { group in
                    group.addTask {
                        _ = try await client.playMedia(
                            queueId: playerId,
                            uri: url
                        )
                        return (true, nil)  // Success
                    }

                    group.addTask {
                        try await Task.sleep(for: .seconds(10))
                        return (false, nil)  // Timeout
                    }

                    guard let (isSuccess, result) = try await group.next() else {
                        throw MAPlayerError.timeout
                    }

                    group.cancelAll()

                    if !isSuccess {
                        throw MAPlayerError.timeout
                    }

                    return result
                }

                print("✓ Play command sent successfully")
                if let result = result {
                    print("   Response: \(String(describing: result.value))")
                } else {
                    print("   Response: (no response)")
                }
                print("")

                // Show the streaming URL
                let streamingUrl = "http://\(host):\(port)/builtin_player/flow/\(playerId).mp3"
                print("🔊 Streaming from:")
                print("   \(streamingUrl)")
                print("   You can also open this URL in a browser or media player!")
                print("")

                // Wait for the specified duration
                print("⏱️  Playing for \(Int(duration)) seconds...")
                print("   (Press Ctrl+C to stop early)")
                print("")

                // Set up signal handling for early exit
                var shouldStop = false

                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
                    sigintSrc.setEventHandler {
                        shouldStop = true
                        continuation.resume()
                    }
                    sigintSrc.resume()
                    signal(SIGINT, SIG_IGN)

                    // Also resume after duration timeout
                    Task {
                        try? await Task.sleep(for: .seconds(duration))
                        if !shouldStop {
                            continuation.resume()
                        }
                    }

                    // Keep signal source alive
                    withExtendedLifetime(sigintSrc) {}
                }

                // Cleanup
                print("")
                if shouldStop {
                    print("⏹️  Stopped by user")
                } else {
                    print("⏹️  Duration elapsed")
                }

                print("🧹 Cleaning up...")
                try? await player.unregister()
                await client.disconnect()
                print("✓ Done")

            } catch MAPlayerError.timeout {
                print("✗ Command timed out after 10 seconds")
                print("")
                print("💡 This usually means:")
                print("   - The Music Assistant server is not responding")
                print("   - The URI format is invalid")
                print("   - Check Music Assistant server logs for errors")
                print("")
                try? await player.unregister()
                await client.disconnect()
                exit(1)
            } catch {
                print("✗ Failed to play: \(error)")
                print("")
                print("💡 Tips:")
                print("   - Make sure the URL is accessible")
                print("   - Try a direct audio file URL (.mp3, .flac, etc.)")
                print("   - Check Music Assistant logs for details")
                print("   - For library URIs, verify the ID exists")
                print("")
                try? await player.unregister()
                await client.disconnect()
                exit(1)
            }
        }

        static func printUsage() {
            print("""
            Usage: ma-player-play <url> [--duration SECONDS]

            Play a URL through Music Assistant built-in player.

            Arguments:
              <url>              URL to play (can be http://, file://, or Music Assistant URI)
              --duration SECONDS Play duration in seconds (default: 30)

            Environment Variables:
              MA_HOST            Music Assistant server host (default: localhost)
              MA_PORT            Music Assistant server port (default: 8095)

            Examples:
              # Play a direct audio URL for 30 seconds
              swift run ma-player-play https://example.com/song.mp3

              # Play for 60 seconds
              swift run ma-player-play https://example.com/song.mp3 --duration 60

              # Play from custom server
              MA_HOST=192.168.1.100 swift run ma-player-play https://example.com/song.mp3

              # Play a Music Assistant library item
              swift run ma-player-play "library://track/123"

            Note: The URL must be a format that Music Assistant can stream.
            Not all URLs will work - Music Assistant needs to recognize and
            process the media type.
            """)
        }
    }

    extension String {
        static func * (lhs: String, rhs: Int) -> String {
            return String(repeating: lhs, count: rhs)
        }
    }
#else
    @main
    struct MAPlayerPlay {
        static func main() {
            print("URL player is only available on macOS and iOS")
        }
    }
#endif
