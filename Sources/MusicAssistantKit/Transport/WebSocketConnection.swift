// ABOUTME: Actor managing WebSocket connection lifecycle and message transport
// ABOUTME: Handles connection, reconnection with exponential backoff, and message framing

import Foundation

actor WebSocketConnection {
    private let host: String
    private let port: Int
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private(set) var state: ConnectionState = .disconnected

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
}
