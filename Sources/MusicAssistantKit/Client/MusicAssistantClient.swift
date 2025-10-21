// ABOUTME: Main Music Assistant client API providing high-level commands and event streams
// ABOUTME: Actor-based design ensures thread-safe state management across async operations

import Combine
import Foundation

public actor MusicAssistantClient {
    private let connection: any WebSocketConnectionProtocol
    private var nextMessageId: Int = 1
    private var pendingCommands: [Int: CheckedContinuation<AnyCodable?, Error>] = [:]
    public let events = EventPublisher()

    public var isConnected: Bool {
        get async {
            await connection.state.isConnected
        }
    }

    public init(host: String, port: Int) {
        connection = WebSocketConnection(host: host, port: port)
    }

    // Test-only initializer for dependency injection
    init(connection: any WebSocketConnectionProtocol) {
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
        case .serverInfo, .unknown:
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

    // MARK: - Streaming Commands (Resonate Protocol Support)

    /// Get streaming URL for a media item
    ///
    /// ⚠️ **EXPERIMENTAL**: Resonate protocol is in active development.
    /// API endpoints may change. Verify against your Music Assistant version.
    ///
    /// - Parameters:
    ///   - mediaItemId: The ID of the media item to stream
    ///   - preferredProtocol: Preferred streaming protocol (defaults to .resonate)
    /// - Returns: StreamingInfo with URL and format details
    /// - Throws: MusicAssistantError if command fails or response is invalid
    /// - Warning: API endpoint is speculative and needs verification against actual Music Assistant implementation
    public func getStreamURL(
        mediaItemId: String,
        preferredProtocol: StreamProtocol = .resonate
    ) async throws -> StreamingInfo? {
        // TODO: VERIFY - This endpoint is speculative as Resonate protocol is experimental
        // Check actual Music Assistant API documentation when available
        let result = try await sendCommand(
            command: "music/get_stream_url",
            args: [
                "media_item_id": mediaItemId,
                "protocol": preferredProtocol.rawValue,
            ]
        )

        return try parseStreamingInfo(from: result)
    }

    /// Get Resonate streaming information for a queue
    ///
    /// ⚠️ **EXPERIMENTAL**: Resonate protocol is in active development.
    /// API endpoints may change. Verify against your Music Assistant version.
    ///
    /// This is used for synchronized multi-room audio playback
    /// - Parameter queueId: The queue/player ID to get Resonate stream for
    /// - Returns: StreamingInfo configured for Resonate protocol
    /// - Throws: MusicAssistantError if command fails or response is invalid
    /// - Warning: API endpoint is speculative and needs verification against actual Music Assistant implementation
    public func getResonateStream(queueId: String) async throws -> StreamingInfo? {
        // TODO: VERIFY - This endpoint is speculative as Resonate protocol is experimental
        // Check actual Music Assistant API documentation when available
        let result = try await sendCommand(
            command: "player_queues/get_resonate_stream",
            args: ["queue_id": queueId]
        )

        return try parseStreamingInfo(from: result)
    }

    /// Parse streaming information from command result
    /// - Parameter result: The AnyCodable result from a streaming command
    /// - Returns: StreamingInfo if parsing succeeds, nil if result is nil
    /// - Throws: MusicAssistantError.invalidResponse if data is not a dictionary,
    ///           or MusicAssistantError.decodingFailed if decoding fails
    private func parseStreamingInfo(from result: AnyCodable?) throws -> StreamingInfo? {
        guard let result else { return nil }

        // Validate that result is a dictionary
        guard let dict = result.value as? [String: Any] else {
            throw MusicAssistantError.invalidResponse
        }

        // Convert to JSON data for decoding
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: dict)
        } catch {
            throw MusicAssistantError.invalidResponse
        }

        // Decode to StreamingInfo
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            return try decoder.decode(StreamingInfo.self, from: data)
        } catch {
            throw MusicAssistantError.decodingFailed(error)
        }
    }

    /// Check if the server supports Resonate protocol
    /// - Returns: true if Resonate protocol is available
    public func supportsResonateProtocol() async -> Bool {
        guard let serverInfo = await getServerInfo() else {
            return false
        }
        return serverInfo.capabilities?.contains("resonate") ?? false
    }

    /// Get server information including capabilities
    /// - Returns: ServerInfo if connected, nil otherwise
    public func getServerInfo() async -> ServerInfo? {
        await connection.serverInfo
    }
}
