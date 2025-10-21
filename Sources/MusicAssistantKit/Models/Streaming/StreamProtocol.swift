// ABOUTME: Enum representing different streaming protocols supported by Music Assistant
// ABOUTME: Resonate is the preferred protocol for synchronized multi-room audio

import Foundation

/// Streaming protocol types supported by Music Assistant
public enum StreamProtocol: String, Codable, Sendable {
    /// Resonate protocol - Synchronized multi-room audio streaming
    /// Provides sub-millisecond synchronization for HiFi multi-room playback
    case resonate

    /// Standard HTTP streaming
    case http

    /// HTTPS streaming
    case https

    /// Direct file access
    case file
}
