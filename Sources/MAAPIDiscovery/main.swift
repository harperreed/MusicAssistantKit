// ABOUTME: CLI tool for discovering Music Assistant API responses
// ABOUTME: Tests music/item_by_uri and captures real JSON structures

import Foundation
import MusicAssistantKit

@main
struct APIDiscovery {
    struct Config {
        let host: String
        let port: Int

        static let `default` = Config(
            host: "192.168.23.196",
            port: 8095
        )
    }

    static func main() async {
        let config = Config.default
        await runDiscovery(config)
    }

    // swiftlint:disable:next function_body_length
    static func runDiscovery(_ config: Config) async {
        let client = MusicAssistantClient(host: config.host, port: config.port)

        do {
            print("🔌 Connecting to Music Assistant at \(config.host):\(config.port)...")
            try await client.connect()
            print("✅ Connected!\n")

            // Step 1: Search for tracks to get a real URI
            print("📋 Step 1: Searching for tracks...")
            print("─────────────────────────────────────────")
            let searchResults = try await client.search(query: "test", limit: 5)

            guard let resultsDict = searchResults?.value as? [String: Any],
                  let tracks = resultsDict["tracks"] as? [[String: Any]],
                  !tracks.isEmpty else {
                print("❌ No tracks found in search results")
                await client.disconnect()
                return
            }

            print("✅ Found \(tracks.count) tracks\n")

            // Display first few tracks
            for (index, track) in tracks.prefix(3).enumerated() {
                let name = track["name"] as? String ?? "Unknown"
                let uri = track["uri"] as? String ?? "Unknown"
                let artists = (track["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
                    .joined(separator: ", ") ?? "Unknown"
                print("  \(index + 1). \(name) - \(artists)")
                print("     URI: \(uri)")
            }

            // Step 2: Query first track with music/item_by_uri
            // Try to find a library:// track first, fallback to any track
            let libraryTrack = tracks.first { track in
                if let uri = track["uri"] as? String {
                    return uri.hasPrefix("library://")
                }
                return false
            }

            let trackToQuery = libraryTrack ?? tracks.first
            guard let trackToQuery,
                  let trackUri = trackToQuery["uri"] as? String else {
                print("\n❌ Could not extract track URI")
                await client.disconnect()
                return
            }

            let trackName = trackToQuery["name"] as? String ?? "Unknown"

            print("\n📋 Step 2: Querying track details...")
            print("─────────────────────────────────────────")
            print("Track: \(trackName)")
            print("URI: \(trackUri)")
            print("Type: \(trackUri.hasPrefix("library://") ? "Library Track" : "Streaming Service")\n")

            let trackDetails = try await client.sendCommand(
                command: "music/item_by_uri",
                args: ["uri": trackUri]
            )

            // Pretty print the JSON response
            print("📦 RESPONSE FROM music/item_by_uri:")
            print("═════════════════════════════════════════")
            if let details = trackDetails {
                prettyPrintJSON(details)
            } else {
                print("(null response)")
            }

            // Step 3: Check if there are any URL fields
            print("\n🔍 Step 3: Analyzing response for URLs...")
            print("─────────────────────────────────────────")
            if let detailsDict = trackDetails?.value as? [String: Any] {
                analyzeForURLs(detailsDict)
            }

            // Step 4: Test for stream URL patterns
            print("\n📋 Step 4: Testing for stream URL patterns...")
            print("─────────────────────────────────────────")
            await testStreamURLPatterns(config: config, trackUri: trackUri)

            // Step 5: Subscribe to player updates and try to capture events
            print("\n📋 Step 5: Attempting to capture player_updated event...")
            print("─────────────────────────────────────────")
            print("(This would require starting playback - skipping for now)")
            print("To capture player events, use MAMonitor while playing a track")

            await client.disconnect()
            print("\n✅ Discovery complete!")
        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
    }

    static func prettyPrintJSON(_ value: AnyCodable) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            if let string = String(data: data, encoding: .utf8) {
                print(string)
            }
        } catch {
            print("Error encoding JSON: \(error)")
            print("\nRaw value: \(value)")
        }
    }

    static func analyzeForURLs(_ dict: [String: Any], prefix: String = "") {
        var foundURLs = false

        for (key, value) in dict {
            let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"

            // Check if this looks like a URL field
            if key.lowercased().contains("url") || key.lowercased().contains("uri") || key.lowercased()
                .contains("stream") {
                print("  🔗 Found URL field: \(fullKey)")
                print("     Type: \(type(of: value))")
                print("     Value: \(value)")
                foundURLs = true
            }

            // Recursively check nested dictionaries
            if let nestedDict = value as? [String: Any] {
                analyzeForURLs(nestedDict, prefix: fullKey)
            }

            // Check arrays of dictionaries
            if let array = value as? [[String: Any]] {
                for (index, item) in array.enumerated() {
                    analyzeForURLs(item, prefix: "\(fullKey)[\(index)]")
                }
            }
        }

        if !foundURLs, prefix.isEmpty {
            print("  ℹ️  No obvious URL/URI/stream fields found at top level")
        }
    }

    static func testStreamURLPatterns(config: Config, trackUri: String) async {
        // Parse provider and item_id from URI
        let uriComponents = trackUri.split(separator: "/")
        guard uriComponents.count >= 3,
              let provider = uriComponents.first?.split(separator: ":").first,
              let itemId = uriComponents.last else {
            print("  ℹ️  Could not parse provider/item_id from URI")
            return
        }

        let providerStr = String(provider)
        let itemIdStr = String(itemId)

        print("  Provider: \(providerStr)")
        print("  Item ID: \(itemIdStr)")
        print("")

        // Test various URL patterns that might exist
        let streamPort = 8097
        let interfacePort = config.port

        let urlsToTest = [
            // Preview URLs (based on Python client)
            "http://\(config.host):\(interfacePort)/preview/\(providerStr)/\(itemIdStr)",
            "http://\(config.host):\(streamPort)/preview/\(providerStr)/\(itemIdStr)",

            // Stream URLs (hypothetical)
            "http://\(config.host):\(streamPort)/stream/\(providerStr)/\(itemIdStr)",
            "http://\(config.host):\(interfacePort)/stream/\(providerStr)/\(itemIdStr)",

            // Audio URLs (hypothetical)
            "http://\(config.host):\(streamPort)/audio/\(providerStr)/\(itemIdStr)",
            "http://\(config.host):\(interfacePort)/audio/\(providerStr)/\(itemIdStr)",
        ]

        print("  Testing potential stream URL patterns:")
        for url in urlsToTest {
            let exists = await testURLExists(url)
            let status = exists ? "✅ EXISTS" : "❌ Not found"
            print("    \(status): \(url)")
        }
    }

    static func testURLExists(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200 ... 299).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            return false
        }
    }
}
