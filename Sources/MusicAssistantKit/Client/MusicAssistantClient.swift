// ABOUTME: Main Music Assistant client API providing high-level commands and event streams
// ABOUTME: Actor-based design ensures thread-safe state management across async operations

import Foundation
import Combine

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
        self.connection = WebSocketConnection(host: host, port: port)
    }

    // Test-only initializer for dependency injection
    internal init(connection: any WebSocketConnectionProtocol) {
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
        case .result(let result):
            if let continuation = pendingCommands.removeValue(forKey: result.messageId) {
                continuation.resume(returning: result.result)
            }
        case .error(let error):
            if let continuation = pendingCommands.removeValue(forKey: error.messageId) {
                let maError = MusicAssistantError.serverError(
                    code: error.errorCode,
                    message: error.error,
                    details: error.details
                )
                continuation.resume(throwing: maError)
            }
        case .event(let event):
            events.publish(event)
        case .serverInfo, .unknown:
            break
        }
    }

    public func sendCommand(command: String, args: [String: Any]? = nil) async throws -> AnyCodable? {
        let messageId = generateMessageId()

        // Convert args to [String: AnyCodable] if present
        let anyCodableArgs: [String: AnyCodable]?
        if let args = args {
            anyCodableArgs = args.mapValues { AnyCodable($0) }
        } else {
            anyCodableArgs = nil
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
        return try await sendCommand(command: "players/all")
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

    // MARK: - Search Commands

    public func search(query: String, limit: Int = 25) async throws -> AnyCodable? {
        return try await sendCommand(
            command: "music/search",
            args: [
                "search_query": query,
                "limit": limit
            ]
        )
    }

    // MARK: - Queue Commands

    public func getQueue(queueId: String) async throws -> AnyCodable? {
        return try await sendCommand(
            command: "player_queues/get",
            args: ["queue_id": queueId]
        )
    }

    public func getQueueItems(queueId: String, limit: Int = 50, offset: Int = 0) async throws -> AnyCodable? {
        return try await sendCommand(
            command: "player_queues/items",
            args: [
                "queue_id": queueId,
                "limit": limit,
                "offset": offset
            ]
        )
    }

    public func playMedia(
        queueId: String,
        uri: String,
        option: String = "play",
        radioMode: Bool = false
    ) async throws -> AnyCodable? {
        return try await sendCommand(
            command: "player_queues/play_media",
            args: [
                "queue_id": queueId,
                "uri": uri,
                "option": option,
                "radio_mode": radioMode
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
                "shuffle": enabled
            ]
        )
    }

    public func setRepeat(queueId: String, mode: String) async throws {
        _ = try await sendCommand(
            command: "player_queues/repeat",
            args: [
                "queue_id": queueId,
                "repeat_mode": mode
            ]
        )
    }
}
