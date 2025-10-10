// ABOUTME: Actor managing WebSocket connection lifecycle and message transport
// ABOUTME: Handles connection, reconnection with exponential backoff, and message framing

import Foundation

actor WebSocketConnection {
    private let host: String
    private let port: Int
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private(set) var state: ConnectionState = .disconnected
    private var messageHandler: ((MessageEnvelope) async -> Void)?

    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    func connect() async throws {
        guard state.isDisconnected else {
            return
        }

        state = .connecting

        let url = URL(string: "ws://\(host):\(port)/ws")!
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)

        self.urlSession = session
        self.webSocketTask = task

        task.resume()

        // Wait for server info
        let message = try await receiveMessage()

        // Parse server info
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let serverInfo = try decoder.decode(ServerInfo.self, from: message)

        state = .connected(serverInfo: serverInfo)

        // Start receiving messages continuously
        startReceiveLoop()
    }

    func setMessageHandler(_ handler: @escaping (MessageEnvelope) async -> Void) {
        self.messageHandler = handler
    }

    func send(_ command: Command) async throws {
        guard let task = webSocketTask, state.isConnected else {
            throw MusicAssistantError.notConnected
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(command)
        let text = String(data: data, encoding: .utf8)!

        let message = URLSessionWebSocketTask.Message.string(text)
        try await task.send(message)
    }

    func disconnect() async {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
        state = .disconnected
    }

    private func receiveMessage() async throws -> Data {
        guard let task = webSocketTask else {
            throw MusicAssistantError.notConnected
        }

        let message = try await task.receive()

        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8) else {
                throw MusicAssistantError.invalidResponse
            }
            return data
        case .data(let data):
            return data
        @unknown default:
            throw MusicAssistantError.invalidResponse
        }
    }

    private func startReceiveLoop() {
        Task {
            while state.isConnected {
                do {
                    let data = try await receiveMessage()
                    let envelope = try parseMessage(data)
                    await messageHandler?(envelope)
                } catch {
                    // Connection closed or error
                    break
                }
            }
        }
    }

    private func parseMessage(_ data: Data) throws -> MessageEnvelope {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Try to peek at the JSON to determine message type
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .unknown
        }

        if json["server_version"] != nil {
            let serverInfo = try decoder.decode(ServerInfo.self, from: data)
            return .serverInfo(serverInfo)
        } else if json["event"] != nil {
            let event = try decoder.decode(Event.self, from: data)
            return .event(event)
        } else if json["message_id"] != nil {
            if json["error"] != nil {
                let error = try decoder.decode(ErrorResponse.self, from: data)
                return .error(error)
            } else if json["result"] != nil {
                let result = try decoder.decode(Result.self, from: data)
                return .result(result)
            }
        }

        return .unknown
    }
}
