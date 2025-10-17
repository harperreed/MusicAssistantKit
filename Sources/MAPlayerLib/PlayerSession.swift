// ABOUTME: Manages MusicAssistantClient connection and AVPlayer state for playback control
// ABOUTME: Actor-isolated for thread-safe access, bridges WebSocket events to AVPlayer

import AVFoundation
import Combine
import Foundation
import MusicAssistantKit

public actor PlayerSession {
    private let client: MusicAssistantClient
    private let playerId: String
    private let audioPlayer: AudioPlayerProtocol
    private var cancellables = Set<AnyCancellable>()

    public init(
        host: String,
        port: Int,
        playerId: String,
        audioPlayer: AudioPlayerProtocol? = nil
    ) async throws {
        client = MusicAssistantClient(host: host, port: port)
        self.playerId = playerId

        if let audioPlayer {
            self.audioPlayer = audioPlayer
        } else {
            self.audioPlayer = await MainActor.run { AVPlayer() }
        }

        try await client.connect()
    }

    deinit {
        Task { [client] in
            await client.disconnect()
        }
    }
}
