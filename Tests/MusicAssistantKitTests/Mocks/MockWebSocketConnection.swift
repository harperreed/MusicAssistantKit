// ABOUTME: Mock WebSocket connection for testing client logic without network dependencies
// ABOUTME: Provides controllable connection state and message handling for unit tests

import Foundation
@testable import MusicAssistantKit

actor MockWebSocketConnection: WebSocketConnectionProtocol {
    var state: ConnectionState = .disconnected
    var messageHandler: ((MessageEnvelope) async -> Void)?
    var sentCommands: [Command] = []
    var shouldFailConnect: Bool = false
    var shouldFailSend: Bool = false
    var connectDelay: UInt64 = 0

    func connect() async throws {
        if shouldFailConnect {
            throw MusicAssistantError.connectionFailed(underlying: NSError(domain: "test", code: -1))
        }

        if connectDelay > 0 {
            try await Task.sleep(nanoseconds: connectDelay)
        }

        let serverInfo = ServerInfo(
            serverVersion: "2.0.0-test",
            schemaVersion: 25,
            minSupportedSchemaVersion: 1,
            serverId: "mock-server",
            homeassistantAddon: false,
            capabilities: ["test"],
            baseUrl: nil,
            onboardDone: true
        )
        state = .connected(serverInfo: serverInfo)
    }

    func disconnect() async {
        state = .disconnected
        sentCommands.removeAll()
    }

    func send(_ command: Command) async throws {
        if shouldFailSend {
            throw MusicAssistantError.notConnected
        }

        guard state.isConnected else {
            throw MusicAssistantError.notConnected
        }

        sentCommands.append(command)
    }

    func setMessageHandler(_ handler: @escaping (MessageEnvelope) async -> Void) {
        self.messageHandler = handler
    }

    // Test helpers
    func simulateMessage(_ envelope: MessageEnvelope) async {
        if let handler = messageHandler {
            await handler(envelope)
        }
    }

    func simulateResult(messageId: Int, result: AnyCodable?) async {
        let resultMessage = Result(messageId: messageId, result: result)
        await simulateMessage(.result(resultMessage))
    }

    func simulateError(messageId: Int, error: String, code: Int? = nil) async {
        let errorResponse = ErrorResponse(
            messageId: messageId,
            error: error,
            errorCode: code,
            details: nil,
            exception: nil,
            stacktrace: nil
        )
        await simulateMessage(.error(errorResponse))
    }

    func simulateEvent(_ event: Event) async {
        await simulateMessage(.event(event))
    }

    func getLastCommand() -> Command? {
        return sentCommands.last
    }

    func getCommandCount() -> Int {
        return sentCommands.count
    }

    func clearCommands() {
        sentCommands.removeAll()
    }
}
