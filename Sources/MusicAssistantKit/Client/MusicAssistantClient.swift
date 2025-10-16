// ABOUTME: Main Music Assistant client API providing high-level commands and event streams
// ABOUTME: Actor-based design ensures thread-safe state management across async operations

import Combine
import Foundation

public actor MusicAssistantClient {
    private let connection: any WebSocketConnectionProtocol
    private var nextMessageId: Int = 1
    private var pendingCommands: [Int: CheckedContinuation<AnyCodable?, Error>] = [:]
    public let events = EventPublisher()
    private var serverInfo: ServerInfo?
    private let host: String?
    private let port: Int?

    public var isConnected: Bool {
        get async {
            await connection.state.isConnected
        }
    }

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
        connection = WebSocketConnection(host: host, port: port)
    }

    // Test-only initializer for dependency injection
    init(connection: any WebSocketConnectionProtocol) {
        self.host = nil
        self.port = nil
        self.connection = connection
    }

    private func setupMessageHandler() async {
        await connection.setMessageHandler { [weak self] envelope in
            await self?.handleMessage(envelope)
        }
    }

    public func connect() async throws {
        await setupMessageHandler()
        try await connection.connect()
    }

    public func disconnect() async {
        await connection.disconnect()

        // Cancel all pending commands
        for (_, continuation) in pendingCommands {
            continuation.resume(throwing: MusicAssistantError.notConnected)
        }
        pendingCommands.removeAll()
    }

    private func generateMessageId() -> Int {
        let id = nextMessageId
        nextMessageId += 1
        return id
    }

    private func timeoutCommand(messageId: Int) {
        if let pending = pendingCommands.removeValue(forKey: messageId) {
            pending.resume(throwing: MusicAssistantError.commandTimeout(messageId: messageId))
        }
    }

    private func handleMessage(_ envelope: MessageEnvelope) async {
        switch envelope {
        case let .result(result):
            if let continuation = pendingCommands.removeValue(forKey: result.messageId) {
                continuation.resume(returning: result.result)
            }
        case let .error(error):
            if let continuation = pendingCommands.removeValue(forKey: error.messageId) {
                let maError = MusicAssistantError.serverError(
                    code: error.errorCode,
                    message: error.error,
                    details: error.details
                )
                continuation.resume(throwing: maError)
            }
        case let .event(event):
            events.publish(event)
        case let .serverInfo(info):
            serverInfo = info
        case .unknown:
            break
        }
    }

    public func sendCommand(command: String, args: [String: Any]? = nil) async throws -> AnyCodable? {
        let messageId = generateMessageId()

        // Convert args to [String: AnyCodable] if present
        let anyCodableArgs: [String: AnyCodable]? = if let args {
            args.mapValues { AnyCodable($0) }
        } else {
            nil
        }

        let cmd = Command(messageId: messageId, command: command, args: anyCodableArgs)

        return try await withCheckedThrowingContinuation { continuation in
            pendingCommands[messageId] = continuation

            Task {
                // Start timeout task first
                let timeoutTask = Task { [weak self] in
                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                    await self?.timeoutCommand(messageId: messageId)
                }

                do {
                    try await connection.send(cmd)
                } catch {
                    // Cancel timeout and resume with error
                    timeoutTask.cancel()
                    if let pending = pendingCommands.removeValue(forKey: messageId) {
                        pending.resume(throwing: error)
                    }
                }
            }
        }
    }

    // MARK: - Player Control Commands

    public func getPlayers() async throws -> AnyCodable? {
        try await sendCommand(command: "players/all")
    }

    public func play(playerId: String) async throws {
        _ = try await sendCommand(
            command: "players/cmd/play",
            args: ["player_id": playerId]
        )
    }

    public func pause(playerId: String) async throws {
        _ = try await sendCommand(
            command: "players/cmd/pause",
            args: ["player_id": playerId]
        )
    }

    public func stop(playerId: String) async throws {
        _ = try await sendCommand(
            command: "players/cmd/stop",
            args: ["player_id": playerId]
        )
    }

    public func next(playerId: String) async throws {
        _ = try await sendCommand(
            command: "players/cmd/next",
            args: ["player_id": playerId]
        )
    }

    public func previous(playerId: String) async throws {
        _ = try await sendCommand(
            command: "players/cmd/previous",
            args: ["player_id": playerId]
        )
    }

    public func setVolume(playerId: String, volume: Double) async throws {
        _ = try await sendCommand(
            command: "players/cmd/volume_set",
            args: [
                "player_id": playerId,
                "volume_level": volume,
            ]
        )
    }

    public func seek(playerId: String, position: Double) async throws {
        _ = try await sendCommand(
            command: "players/cmd/seek",
            args: [
                "player_id": playerId,
                "position": position,
            ]
        )
    }

    public func group(playerId: String, targetPlayer: String) async throws {
        _ = try await sendCommand(
            command: "players/cmd/group",
            args: [
                "player_id": playerId,
                "target_player": targetPlayer,
            ]
        )
    }

    public func ungroup(playerId: String) async throws {
        _ = try await sendCommand(
            command: "players/cmd/ungroup",
            args: ["player_id": playerId]
        )
    }

    // MARK: - Search Commands

    public func search(query: String, limit: Int = 25) async throws -> AnyCodable? {
        try await sendCommand(
            command: "music/search",
            args: [
                "search_query": query,
                "limit": limit,
            ]
        )
    }

    // MARK: - Queue Commands

    public func getQueue(queueId: String) async throws -> AnyCodable? {
        try await sendCommand(
            command: "player_queues/get",
            args: ["queue_id": queueId]
        )
    }

    public func getQueueItems(queueId: String, limit: Int = 50, offset: Int = 0) async throws -> AnyCodable? {
        try await sendCommand(
            command: "player_queues/items",
            args: [
                "queue_id": queueId,
                "limit": limit,
                "offset": offset,
            ]
        )
    }

    public func playMedia(
        queueId: String,
        uri: String,
        option: String = "play",
        radioMode: Bool = false
    ) async throws -> AnyCodable? {
        try await sendCommand(
            command: "player_queues/play_media",
            args: [
                "queue_id": queueId,
                "uri": uri,
                "option": option,
                "radio_mode": radioMode,
            ]
        )
    }

    public func clearQueue(queueId: String) async throws {
        _ = try await sendCommand(
            command: "player_queues/clear",
            args: ["queue_id": queueId]
        )
    }

    public func shuffle(queueId: String, enabled: Bool) async throws {
        _ = try await sendCommand(
            command: "player_queues/shuffle",
            args: [
                "queue_id": queueId,
                "shuffle": enabled,
            ]
        )
    }

    public func setRepeat(queueId: String, mode: String) async throws {
        _ = try await sendCommand(
            command: "player_queues/repeat",
            args: [
                "queue_id": queueId,
                "repeat_mode": mode,
            ]
        )
    }

    public func seek(queueId: String, position: Double) async throws {
        _ = try await sendCommand(
            command: "player_queues/seek",
            args: [
                "queue_id": queueId,
                "position": position,
            ]
        )
    }

    // MARK: - Stream URL Construction

    /// Get base URL for constructing stream URLs
    private func getBaseURL() throws -> URL {
        // Try to use base URL from server info first
        if let info = serverInfo, let baseUrlString = info.baseUrl {
            guard let baseURL = URL(string: baseUrlString) else {
                throw MusicAssistantError.invalidURL(baseUrlString)
            }
            return baseURL
        }

        // Fall back to constructing from host/port
        guard let host = host, let port = port else {
            throw MusicAssistantError.notConnected
        }
        return URL(string: "http://\(host):\(port)")!
    }

    /// Construct full stream URL from media path received in events
    /// - Parameter mediaPath: Media path from BUILTIN_PLAYER event (e.g., "flow/session/queue/item.mp3")
    /// - Returns: Complete StreamURL ready for playback
    /// - Throws: MusicAssistantError.notConnected if not connected to server
    public func getStreamURL(mediaPath: String) throws -> StreamURL {
        let baseURL = try getBaseURL()
        return StreamURL(baseURL: baseURL, mediaPath: mediaPath)
    }

    /// Construct queue stream URL for specific queue item
    /// - Parameters:
    ///   - sessionId: Active session ID
    ///   - queueId: Queue ID
    ///   - queueItemId: Queue item ID
    ///   - format: Audio format (mp3, flac, pcm)
    ///   - flowMode: true for gapless flow, false for single item
    /// - Returns: StreamURL for the queue item
    /// - Throws: MusicAssistantError.notConnected if not connected to server
    public func constructQueueStreamURL(
        sessionId: String,
        queueId: String,
        queueItemId: String,
        format: StreamFormat,
        flowMode: Bool = true
    ) throws -> StreamURL {
        let baseURL = try getBaseURL()
        return StreamURL.queueStream(
            baseURL: baseURL,
            sessionId: sessionId,
            queueId: queueId,
            queueItemId: queueItemId,
            format: format,
            flowMode: flowMode
        )
    }

    /// Construct preview/clip URL for track
    /// - Parameters:
    ///   - itemId: Track item ID
    ///   - provider: Provider instance (e.g., "library", "spotify")
    /// - Returns: StreamURL for preview audio
    /// - Throws: MusicAssistantError.notConnected if not connected to server, or StreamURLError if URL construction fails
    public func constructPreviewURL(itemId: String, provider: String) throws -> StreamURL {
        let baseURL = try getBaseURL()
        return try StreamURL.preview(baseURL: baseURL, itemId: itemId, provider: provider)
    }

    /// Construct announcement URL
    /// - Parameters:
    ///   - playerId: Player ID
    ///   - format: Audio format
    ///   - preAnnounce: Include pre-announce alert
    /// - Returns: StreamURL for announcement
    /// - Throws: MusicAssistantError.notConnected if not connected to server, or StreamURLError if URL construction fails
    public func constructAnnouncementURL(
        playerId: String,
        format: StreamFormat,
        preAnnounce: Bool = false
    ) throws -> StreamURL {
        let baseURL = try getBaseURL()
        return try StreamURL.announcement(
            baseURL: baseURL,
            playerId: playerId,
            format: format,
            preAnnounce: preAnnounce
        )
    }

    /// Construct plugin source URL
    /// - Parameters:
    ///   - pluginSource: Plugin source identifier
    ///   - playerId: Player ID
    ///   - format: Audio format
    /// - Returns: StreamURL for plugin audio
    /// - Throws: MusicAssistantError.notConnected if not connected to server
    public func constructPluginSourceURL(
        pluginSource: String,
        playerId: String,
        format: StreamFormat
    ) throws -> StreamURL {
        let baseURL = try getBaseURL()
        return StreamURL.pluginSource(
            baseURL: baseURL,
            pluginSource: pluginSource,
            playerId: playerId,
            format: format
        )
    }
}
