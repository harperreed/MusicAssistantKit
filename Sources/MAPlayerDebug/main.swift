// ABOUTME: Debug tool to inspect built-in player registration and responses
// ABOUTME: Helps troubleshoot why players may not appear in Music Assistant

import Foundation
import MusicAssistantKit

@main
struct MAPlayerDebug {
    static func main() async throws {
        let host = ProcessInfo.processInfo.environment["MA_HOST"] ?? "localhost"
        let port = Int(ProcessInfo.processInfo.environment["MA_PORT"] ?? "8095") ?? 8095

        print("🔍 Music Assistant Player Registration Debug")
        print("=" * 50)
        print("Connecting to \(host):\(port)...")

        let client = MusicAssistantClient(host: host, port: port)
        try await client.connect()
        print("✓ Connected\n")

        // Test registration
        print("📝 Attempting player registration...")
        print("   Player name: Test Debug Player")
        print("   Player ID: (auto-generated)\n")

        let result = try await client.registerBuiltinPlayer(
            playerName: "Test Debug Player",
            playerId: nil
        )

        print("📥 Registration Response:")
        print("   Raw result: \(String(describing: result))")
        print("   Result value: \(String(describing: result?.value))")

        if let dict = result?.value as? [String: Any] {
            print("\n   Parsed as dictionary:")
            for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                print("      \(key): \(value)")
            }

            if let playerId = dict["player_id"] as? String {
                print("\n✓ Player ID extracted: \(playerId)")

                // Try to get player info
                print("\n🔍 Fetching player info...")
                let players = try await client.getPlayers()
                print("   All players response: \(String(describing: players))")

                if let playersArray = players?.value as? [[String: Any]] {
                    print("\n   Found \(playersArray.count) total players")

                    // Look for our player
                    if let ourPlayer = playersArray.first(where: { ($0["player_id"] as? String) == playerId }) {
                        print("\n✓ Our player found in list:")
                        for (key, value) in ourPlayer.sorted(by: { $0.key < $1.key }) {
                            print("      \(key): \(value)")
                        }
                    } else {
                        print("\n✗ Our player NOT found in players list!")
                        print("   Expected player_id: \(playerId)")
                    }
                }

                // Unregister
                print("\n🧹 Cleaning up - unregistering player...")
                try await client.unregisterBuiltinPlayer(playerId: playerId)
                print("✓ Unregistered")
            } else {
                print("\n✗ Failed to extract player_id from response")
            }
        } else {
            print("\n✗ Response is not a dictionary!")
        }

        await client.disconnect()
        print("\n✓ Disconnected")
    }
}

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
