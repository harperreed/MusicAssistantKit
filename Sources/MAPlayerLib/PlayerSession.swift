// ABOUTME: Manages MusicAssistantClient connection and AVPlayer state for playback control
// ABOUTME: Actor-isolated for thread-safe access, bridges WebSocket events to AVPlayer

import AVFoundation
@preconcurrency import Combine
import Foundation
import MusicAssistantKit

public enum MAPlayerError: LocalizedError {
    case invalidVolume(Int)
    case connectionFailed(String)
    case playbackFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidVolume(level):
            "Invalid volume level: \(level). Must be 0-100."
        case let .connectionFailed(reason):
            "Connection failed: \(reason)"
        case let .playbackFailed(reason):
            "Playback failed: \(reason)"
        }
    }
}

public struct StreamInfo: Sendable {
    public let event: BuiltinPlayerEvent
    public let streamURL: String?
    public let timestamp: Date
}

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

    public func next() async throws {
        try await client.next(playerId: playerId)
    }

    public func previous() async throws {
        try await client.previous(playerId: playerId)
    }

    public func pause() async {
        await MainActor.run {
            audioPlayer.pause()
        }
    }

    public func resume() async {
        await MainActor.run {
            audioPlayer.play()
        }
    }

    public func stop() async throws {
        try await client.stop(playerId: playerId)
        await MainActor.run {
            audioPlayer.pause()
        }
    }

    public func setVolume(_ level: Int) async throws {
        guard level >= 0, level <= 100 else {
            throw MAPlayerError.invalidVolume(level)
        }

        try await client.setVolume(
            playerId: playerId,
            volume: Double(level)
        )
    }

    public nonisolated var streamEvents: AsyncStream<StreamInfo> {
        AsyncStream { continuation in
            Task { [client, playerId] in
                let events = await client.events

                let cancellable = events.builtinPlayerEvents
                    .filter { event in
                        (event.queueId?.contains(playerId) ?? false) && event.command == .playMedia
                    }
                    .sink { event in
                        Task { [client] in
                            var streamURL: String?
                            if let mediaUrl = event.mediaUrl {
                                streamURL = try? await client.getStreamURL(mediaPath: mediaUrl).url.absoluteString
                            }

                            let info = StreamInfo(
                                event: event,
                                streamURL: streamURL,
                                timestamp: Date()
                            )

                            continuation.yield(info)
                        }
                    }

                continuation.onTermination = { @Sendable _ in
                    cancellable.cancel()
                }
            }
        }
    }

    public func getQueue() async throws -> AnyCodable? {
        try await client.getQueueItems(queueId: playerId)
    }

    public func clearQueue() async throws {
        try await client.clearQueue(queueId: playerId)
    }
}
