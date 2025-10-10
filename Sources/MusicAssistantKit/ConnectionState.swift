// ABOUTME: Connection state machine for Music Assistant WebSocket lifecycle
// ABOUTME: Tracks current connection status including reconnection attempts and delays

import Foundation

public enum ConnectionState: Sendable {
    case disconnected
    case connecting
    case connected(serverInfo: ServerInfo)
    case reconnecting(attempt: Int, delay: TimeInterval)
    case failed(error: Error)

    public var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }

    public var isDisconnected: Bool {
        if case .disconnected = self {
            return true
        }
        return false
    }

    public var isReconnecting: Bool {
        if case .reconnecting = self {
            return true
        }
        return false
    }
}
