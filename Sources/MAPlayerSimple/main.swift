// ABOUTME: Ultra-simple test of playing a URI without using StreamingPlayer
// ABOUTME: Helps isolate whether the issue is with playMedia or the player itself

import Foundation
import MusicAssistantKit

@main
struct MAPlayerSimple {
    static func main() async throws {
        let host = ProcessInfo.processInfo.environment["MA_HOST"] ?? "localhost"
        let port = Int(ProcessInfo.processInfo.environment["MA_PORT"] ?? "8095") ?? 8095

        guard CommandLine.arguments.count >= 2 else {
            print("Usage: ma-player-simple <queue_id> <uri>")
            print("Example: ma-player-simple ma_abc123 library://radio/15")
            exit(1)
        }

        let queueId = CommandLine.arguments[1]
        let uri = CommandLine.arguments[2]

        print("Simple playMedia Test")
        print("=" * 50)
        print("Server: \(host):\(port)")
        print("Queue ID: \(queueId)")
        print("URI: \(uri)")
        print("")

        let client = MusicAssistantClient(host: host, port: port)

        print("Connecting...")
        try await client.connect()
        print("✓ Connected")
        print("")

        print("Calling playMedia...")
        print("(This will timeout after 30 seconds if server doesn't respond)")
        print("")

        do {
            let result = try await client.playMedia(queueId: queueId, uri: uri)
            print("✓ Success!")
            print("Response: \(String(describing: result))")
        } catch {
            print("✗ Error: \(error)")
        }

        print("")
        print("Disconnecting...")
        await client.disconnect()
        print("✓ Done")
    }
}

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
