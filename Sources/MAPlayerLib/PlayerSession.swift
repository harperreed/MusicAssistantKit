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
        await setupStreamListener()
    }

    deinit {
        Task { [client] in
            await client.disconnect()
        }
    }

    private func setupStreamListener() async {
        let events = await client.events
        let playerId = playerId

        events.builtinPlayerEvents
            .filter { event in
                (event.queueId?.contains(playerId) ?? false) && event.command == .playMedia
            }
            .sink { [weak self] event in
                guard let self else { return }
                Task {
                    await self.handleStreamEvent(event)
                }
            }
            .store(in: &cancellables)
    }

    public func handleStreamEvent(_ event: BuiltinPlayerEvent) async {
        guard event.command == .playMedia,
              let mediaUrl = event.mediaUrl else { return }

        do {
            let streamURL = try await client.getStreamURL(mediaPath: mediaUrl)
            await MainActor.run {
                audioPlayer.replaceCurrentItem(with: streamURL.url)
                audioPlayer.play()
            }
        } catch {
            // TODO: Replace with proper error handling/logging mechanism
            // For now, failing silently as there's no error handler to propagate to
            return
        }
    }

    public func startPlayback(uri: String) async throws {
        _ = try await client.playMedia(
            queueId: playerId,
            uri: uri
        )
    }
}
