// ABOUTME: Discriminated union for incoming WebSocket messages from Music Assistant
// ABOUTME: Routes to appropriate message type based on presence of message_id and event fields

import Foundation

enum MessageEnvelope {
    case serverInfo(ServerInfo)
    case result(Result)
    case error(ErrorResponse)
    case event(Event)
    case unknown
}
