// ABOUTME: Protocol defining WebSocket connection interface for dependency injection
// ABOUTME: Enables testing by allowing mock implementations of connection behavior

import Foundation

public protocol WebSocketConnectionProtocol: Actor {
    var state: ConnectionState { get async }
    var serverInfo: ServerInfo? { get async }

    func connect() async throws
    func disconnect() async
    func send(_ command: Command) async throws
    func setMessageHandler(_ handler: @escaping (MessageEnvelope) async -> Void)
}
