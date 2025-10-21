// ABOUTME: AVFoundation-based streaming player that registers as a built-in player with Music Assistant
// ABOUTME: Handles audio playback, state updates, and responds to server commands via events

import AVFoundation
import Combine
import Foundation

@available(macOS 12.0, iOS 15.0, *)
public actor StreamingPlayer {
    private let client: MusicAssistantClient
    private let playerName: String
    private var playerId: String?
    private var player: AVPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var stateUpdateTask: Task<Void, Never>?
    private var timeObserver: Any?

    // Current state
    private var powered: Bool = false
    private var volume: Double = 50.0
    private var muted: Bool = false
    private var currentPosition: Double = 0.0

    public init(client: MusicAssistantClient, playerName: String) {
        self.client = client
        self.playerName = playerName
    }

    /// Register the player with Music Assistant
    public func register() async throws {
        // Register with server
        let result = try await client.registerBuiltinPlayer(playerName: playerName, playerId: playerId)

        // Extract player_id from result
        if let resultDict = result?.value as? [String: Any],
           let id = resultDict["player_id"] as? String
        {
            playerId = id
        } else {
            throw MusicAssistantError.invalidResponse
        }

        // Subscribe to built-in player events
        await subscribeToEvents()

        // Start periodic state updates
        startStateUpdates()
    }

    /// Unregister the player from Music Assistant
    public func unregister() async throws {
        guard let playerId else { return }

        // Stop state updates
        stateUpdateTask?.cancel()
        stateUpdateTask = nil

        // Stop playback
        await stopPlayback()

        // Unregister from server
        _ = try await client.unregisterBuiltinPlayer(playerId: playerId)

        // Clear player ID
        self.playerId = nil
    }

    private func subscribeToEvents() async {
        client.events.builtinPlayerEvents
            .sink { [weak self] playerId, event in
                guard let self else { return }
                Task { [weak self] in
                    await self?.handleEvent(playerId: playerId, event: event)
                }
            }
            .store(in: &cancellables)
    }

    private func handleEvent(playerId: String, event: BuiltinPlayerEvent) async {
        // Only handle events for this player
        guard playerId == self.playerId else { return }

        switch event.type {
        case .playMedia:
            if let mediaUrl = event.mediaUrl {
                await playMedia(urlPath: mediaUrl)
            }

        case .play:
            await play()

        case .pause:
            await pause()

        case .stop:
            await stop()

        case .setVolume:
            if let volume = event.volume {
                await setVolume(volume)
            }

        case .mute:
            await setMuted(true)

        case .unmute:
            await setMuted(false)

        case .powerOn:
            await setPower(true)

        case .powerOff:
            await setPower(false)

        case .timeout:
            // Player timed out, should re-register if desired
            break
        }
    }

    private func playMedia(urlPath: String) async {
        powered = true

        // Construct full URL
        guard let baseURL = await getBaseURL()
        else { return }

        let streamURL = baseURL.appendingPathComponent(urlPath)

        // Create or update player
        if player == nil {
            player = AVPlayer()
            setupTimeObserver()
        }

        let playerItem = AVPlayerItem(url: streamURL)
        player?.replaceCurrentItem(with: playerItem)
        player?.volume = Float(volume / 100.0)
        player?.isMuted = muted
        player?.play()

        await sendStateUpdate()
    }

    private func play() async {
        guard player != nil else { return }
        player?.play()
        powered = true
        await sendStateUpdate()
    }

    private func pause() async {
        guard player != nil else { return }
        player?.pause()
        await sendStateUpdate()
    }

    private func stop() async {
        await stopPlayback()
        await sendStateUpdate()
    }

    private func stopPlayback() async {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player = nil
    }

    private func setVolume(_ volume: Double) async {
        self.volume = volume
        player?.volume = Float(volume / 100.0)
        await sendStateUpdate()
    }

    private func setMuted(_ muted: Bool) async {
        self.muted = muted
        player?.isMuted = muted
        await sendStateUpdate()
    }

    private func setPower(_ powered: Bool) async {
        self.powered = powered
        if !powered {
            await stopPlayback()
        }
        await sendStateUpdate()
    }

    private func setupTimeObserver() {
        guard let player else { return }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            Task { [weak self] in
                await self?.updateCurrentPosition(time.seconds)
            }
        }
    }

    private func updateCurrentPosition(_ position: Double) {
        currentPosition = position
    }

    private nonisolated func getBaseURL() async -> URL? {
        // Construct base URL from client's host and port
        let host = await client.host
        let port = await client.port
        return URL(string: "http://\(host):\(port)")
    }

    private func startStateUpdates() {
        stateUpdateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                await self?.sendStateUpdate()
            }
        }
    }

    private func sendStateUpdate() async {
        guard let playerId else { return }

        let isPlaying = player?.rate ?? 0 > 0
        let isPaused = player != nil && !(player?.rate ?? 0 > 0)

        let state = BuiltinPlayerState(
            powered: powered,
            playing: isPlaying,
            paused: isPaused,
            position: currentPosition,
            volume: volume,
            muted: muted
        )

        do {
            _ = try await client.updateBuiltinPlayerState(playerId: playerId, state: state)
        } catch {
            // Log error but don't crash
            print("Failed to update player state: \(error)")
        }
    }

    /// Get the current player ID (if registered)
    public nonisolated var currentPlayerId: String? {
        get async {
            await playerId
        }
    }
}
