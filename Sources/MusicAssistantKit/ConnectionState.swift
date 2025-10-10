// ABOUTME: Connection state machine for Music Assistant WebSocket lifecycle
// ABOUTME: Tracks current connection status including reconnection attempts and delays

import Foundation

public enum ConnectionState {
    case disconnected
    case connecting
    case connected(serverInfo: ServerInfo)
    case reconnecting(attempt: Int, delay: TimeInterval)
    case failed(error: Error)

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }

    var isDisconnected: Bool {
        if case .disconnected = self {
            return true
        }
        return false
    }

    var isReconnecting: Bool {
        if case .reconnecting = self {
            return true
        }
        return false
    }
}
