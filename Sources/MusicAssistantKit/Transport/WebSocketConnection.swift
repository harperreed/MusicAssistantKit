// ABOUTME: Actor managing WebSocket connection lifecycle and message transport
// ABOUTME: Handles connection, reconnection with exponential backoff, and message framing

import Foundation

actor WebSocketConnection: WebSocketConnectionProtocol {
    private let host: String
    private let port: Int
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    public private(set) var state: ConnectionState = .disconnected
    private var messageHandler: ((MessageEnvelope) async -> Void)?
    private var shouldReconnect: Bool = true
    private var reconnectAttempt: Int = 0
    private let maxReconnectDelay: UInt64 = 60_000_000_000 // 60 seconds in nanoseconds

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    public func connect() async throws {
        guard state.isDisconnected else {
            return
        }

        state = .connecting

        guard let url = URL(string: "ws://\(host):\(port)/ws") else {
            throw MusicAssistantError.invalidResponse
        }
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)

        self.urlSession = session
        self.webSocketTask = task

        task.resume()

        // Wait for server info
        let message = try await receiveMessage()

        // Parse server info
        let decoder = JSONDecoder()
        // Don't use convertFromSnakeCase - we have explicit CodingKeys
        let serverInfo = try decoder.decode(ServerInfo.self, from: message)

        state = .connected(serverInfo: serverInfo)

        // Start receiving messages continuously
        startReceiveLoop()
    }

    public func setMessageHandler(_ handler: @escaping (MessageEnvelope) async -> Void) {
        self.messageHandler = handler
    }

    public func send(_ command: Command) async throws {
        guard let task = webSocketTask, state.isConnected else {
            throw MusicAssistantError.notConnected
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(command)

        guard let text = String(data: data, encoding: .utf8) else {
            throw MusicAssistantError.invalidResponse
        }

        let message = URLSessionWebSocketTask.Message.string(text)
        try await task.send(message)
    }

    public func disconnect() async {
        shouldReconnect = false
        reconnectAttempt = 0
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
        state = .disconnected
    }

    func forceDisconnect() async {
        webSocketTask?.cancel(with: .abnormalClosure, reason: nil)
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
                    if let handler = messageHandler {
                        await handler(envelope)
                    }
                } catch {
                    // Connection closed or error
                    if shouldReconnect {
                        await attemptReconnect()
                    }
                    break
                }
            }
        }
    }

    private func attemptReconnect() async {
        state = .disconnected

        while shouldReconnect {
            reconnectAttempt += 1

            // Calculate exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s, max 60s
            let delaySeconds = min(Int(pow(2.0, Double(reconnectAttempt - 1))), 60)
            let delayNanoseconds = UInt64(delaySeconds) * 1_000_000_000

            do {
                try await Task.sleep(nanoseconds: min(delayNanoseconds, maxReconnectDelay))
            } catch {
                // Task was cancelled
                return
            }

            do {
                try await connect()
                reconnectAttempt = 0
                return
            } catch {
                // Reconnection failed, will retry
                continue
            }
        }
    }

    private func parseMessage(_ data: Data) throws -> MessageEnvelope {
        let decoder = JSONDecoder()
        // Don't use convertFromSnakeCase - we have explicit CodingKeys

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
