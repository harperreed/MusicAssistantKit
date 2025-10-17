import Foundation
import MusicAssistantKit

@main
struct DebugPlayerData {
    static func main() async throws {
        let client = MusicAssistantClient(host: "192.168.23.196", port: 8095)
        try await client.connect()
        
        print("Fetching players...")
        let response = try await client.getPlayers()
        
        print("\nRaw response type: \(type(of: response))")
        print("Response value type: \(type(of: response?.value))")
        
        if let data = response?.value {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("\nFull response:\n\(jsonString)")
            }
        }
        
        // Try to find our player
        if let players = response?.value as? [[String: Any]] {
            print("\n\nFound \(players.count) players")
            if let player = players.first(where: { ($0["player_id"] as? String) == "RINCON_949F3E56293C01400" }) {
                print("\nPlayer data:")
                for (key, value) in player.sorted(by: { $0.key < $1.key }) {
                    print("  \(key): \(value) (\(type(of: value)))")
                }
            } else {
                print("\nPlayer not found! Keys in first player:")
                if let first = players.first {
                    for key in first.keys.sorted() {
                        print("  - \(key)")
                    }
                }
            }
        }
        
        await client.disconnect()
    }
}
