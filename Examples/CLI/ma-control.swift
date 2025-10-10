#!/usr/bin/env swift

// ABOUTME: CLI tool for controlling Music Assistant players (play, pause, stop)
// ABOUTME: Usage: swift ma-control.swift <player-id> <play|pause|stop>

import Foundation

// Add the MusicAssistantKit import path
#if canImport(MusicAssistantKit)
import MusicAssistantKit
#else
print("⚠️  MusicAssistantKit not found. Run from package root or add to swift include path.")
exit(1)
#endif

let host = "192.168.23.196"
let port = 8095

// Parse arguments
guard CommandLine.arguments.count >= 3 else {
    print("Usage: swift ma-control.swift <player-id> <play|pause|stop>")
    print("Example: swift ma-control.swift media_player.kitchen play")
    exit(1)
}

let playerId = CommandLine.arguments[1]
let command = CommandLine.arguments[2].lowercased()

guard ["play", "pause", "stop"].contains(command) else {
    print("❌ Invalid command. Use: play, pause, or stop")
    exit(1)
}

@main
struct MusicControl {
    static func main() async {
        let client = MusicAssistantClient(host: host, port: port)

        do {
            print("🔌 Connecting to Music Assistant at \(host):\(port)...")
            try await client.connect()
            print("✅ Connected!")

            print("🎵 Sending \(command) command to \(playerId)...")

            switch command {
            case "play":
                try await client.play(playerId: playerId)
                print("▶️  Playing")
            case "pause":
                try await client.pause(playerId: playerId)
                print("⏸️  Paused")
            case "stop":
                try await client.stop(playerId: playerId)
                print("⏹️  Stopped")
            default:
                break
            }

            await client.disconnect()
            print("👋 Disconnected")

        } catch {
            print("❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }
}
