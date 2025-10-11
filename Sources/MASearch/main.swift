// ABOUTME: CLI tool for searching Music Assistant library
// ABOUTME: Usage: ma-search <query>

import Foundation
import MusicAssistantKit

@main
struct MusicSearch {
    static func main() async {
        // Parse arguments
        guard CommandLine.arguments.count >= 2 else {
            print("Usage: ma-search [--host HOST] [--port PORT] <query>")
            print("Example: ma-search 'Queen'")
            print("Example: ma-search --host 192.168.1.100 --port 8095 'Beatles'")
            exit(1)
        }

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

        guard !args.isEmpty else {
            print("❌ Missing required argument: <query>")
            exit(1)
        }

        let query = args.joined(separator: " ")

        let client = MusicAssistantClient(host: host, port: port)

        do {
            print("🔌 Connecting to Music Assistant at \(host):\(port)...")
            try await client.connect()
            print("✅ Connected!")

            print("🔍 Searching for '\(query)'...")
            let results = try await client.search(query: query, limit: 10)

            if let resultsDict = results?.value as? [String: Any] {
                print("\n📊 Search Results:")
                print("─────────────────────────────────────────")

                // Display tracks
                if let tracks = resultsDict["tracks"] as? [[String: Any]], !tracks.isEmpty {
                    print("\n🎵 Tracks:")
                    for (index, track) in tracks.enumerated() {
                        let name = track["name"] as? String ?? "Unknown"
                        let artists = (track["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
                            .joined(separator: ", ") ?? "Unknown Artist"
                        let duration = track["duration"] as? Double ?? 0
                        let minutes = Int(duration) / 60
                        let seconds = Int(duration) % 60
                        print("  \(index + 1). \(name) - \(artists) [\(minutes):\(String(format: "%02d", seconds))]")
                    }
                }

                // Display albums
                if let albums = resultsDict["albums"] as? [[String: Any]], !albums.isEmpty {
                    print("\n💿 Albums:")
                    for (index, album) in albums.enumerated() {
                        let name = album["name"] as? String ?? "Unknown"
                        let artists = (album["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
                            .joined(separator: ", ") ?? "Unknown Artist"
                        print("  \(index + 1). \(name) - \(artists)")
                    }
                }

                // Display artists
                if let artists = resultsDict["artists"] as? [[String: Any]], !artists.isEmpty {
                    print("\n👤 Artists:")
                    for (index, artist) in artists.enumerated() {
                        let name = artist["name"] as? String ?? "Unknown"
                        print("  \(index + 1). \(name)")
                    }
                }

                // Display playlists
                if let playlists = resultsDict["playlists"] as? [[String: Any]], !playlists.isEmpty {
                    print("\n📝 Playlists:")
                    for (index, playlist) in playlists.enumerated() {
                        let name = playlist["name"] as? String ?? "Unknown"
                        let owner = playlist["owner"] as? String ?? "Unknown"
                        print("  \(index + 1). \(name) (by \(owner))")
                    }
                }
            } else {
                print("No results found.")
            }

            await client.disconnect()
            print("\n👋 Disconnected")

        } catch {
            print("❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }
}
