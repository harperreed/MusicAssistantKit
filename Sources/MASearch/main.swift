// ABOUTME: CLI tool for searching Music Assistant library
// ABOUTME: Usage: ma-search <query>

import Foundation
import MusicAssistantKit

@main
struct MusicSearch {
    struct Arguments {
        let host: String
        let port: Int
        let query: String

        static func parse() -> Arguments? {
            guard CommandLine.arguments.count >= 2 else {
                printUsage()
                return nil
            }

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

            guard !args.isEmpty else {
                print("❌ Missing required argument: <query>")
                return nil
            }

            let query = args.joined(separator: " ")
            return Arguments(host: host, port: port, query: query)
        }

        static func printUsage() {
            print("Usage: ma-search [--host HOST] [--port PORT] <query>")
            print("Example: ma-search 'Queen'")
            print("Example: ma-search --host 192.168.1.100 --port 8095 'Beatles'")
        }
    }

    static func main() async {
        guard let args = Arguments.parse() else {
            exit(1)
        }

        await performSearch(args)
    }

    static func performSearch(_ args: Arguments) async {
        let client = MusicAssistantClient(host: args.host, port: args.port)

        do {
            print("🔌 Connecting to Music Assistant at \(args.host):\(args.port)...")
            try await client.connect()
            print("✅ Connected!")

            print("🔍 Searching for '\(args.query)'...")
            let results = try await client.search(query: args.query, limit: 10)

            if let resultsDict = results?.value as? [String: Any] {
                displayResults(resultsDict)
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

    static func displayResults(_ resultsDict: [String: Any]) {
        print("\n📊 Search Results:")
        print("─────────────────────────────────────────")

        displayTracks(resultsDict)
        displayAlbums(resultsDict)
        displayArtists(resultsDict)
        displayPlaylists(resultsDict)
    }

    static func displayTracks(_ resultsDict: [String: Any]) {
        guard let tracks = resultsDict["tracks"] as? [[String: Any]], !tracks.isEmpty else {
            return
        }

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

    static func displayAlbums(_ resultsDict: [String: Any]) {
        guard let albums = resultsDict["albums"] as? [[String: Any]], !albums.isEmpty else {
            return
        }

        print("\n💿 Albums:")
        for (index, album) in albums.enumerated() {
            let name = album["name"] as? String ?? "Unknown"
            let artists = (album["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
                .joined(separator: ", ") ?? "Unknown Artist"
            print("  \(index + 1). \(name) - \(artists)")
        }
    }

    static func displayArtists(_ resultsDict: [String: Any]) {
        guard let artists = resultsDict["artists"] as? [[String: Any]], !artists.isEmpty else {
            return
        }

        print("\n👤 Artists:")
        for (index, artist) in artists.enumerated() {
            let name = artist["name"] as? String ?? "Unknown"
            print("  \(index + 1). \(name)")
        }
    }

    static func displayPlaylists(_ resultsDict: [String: Any]) {
        guard let playlists = resultsDict["playlists"] as? [[String: Any]], !playlists.isEmpty else {
            return
        }

        print("\n📝 Playlists:")
        for (index, playlist) in playlists.enumerated() {
            let name = playlist["name"] as? String ?? "Unknown"
            let owner = playlist["owner"] as? String ?? "Unknown"
            print("  \(index + 1). \(name) (by \(owner))")
        }
    }
}
