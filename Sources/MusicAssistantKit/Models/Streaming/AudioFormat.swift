// ABOUTME: Audio format information for streaming
// ABOUTME: Contains codec, sample rate, bit depth, and bitrate information

import Foundation

/// Audio format specification for streaming
public struct AudioFormat: Codable, Sendable {
    /// Audio codec (e.g., "flac", "mp3", "aac", "opus")
    public let codec: String

    /// Sample rate in Hz (e.g., 44100, 48000, 96000)
    public let sampleRate: Int?

    /// Bit depth (e.g., 16, 24, 32)
    public let bitDepth: Int?

    /// Bitrate in kbps (e.g., 320 for MP3, or actual bitrate for variable formats)
    public let bitrate: Int?

    /// Number of channels (e.g., 2 for stereo, 6 for 5.1)
    public let channels: Int?

    /// Whether this is a lossless format
    public var isLossless: Bool {
        ["flac", "alac", "wav", "aiff"].contains(codec.lowercased())
    }

    public init(
        codec: String,
        sampleRate: Int? = nil,
        bitDepth: Int? = nil,
        bitrate: Int? = nil,
        channels: Int? = nil
    ) {
        self.codec = codec
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.bitrate = bitrate
        self.channels = channels
    }

    enum CodingKeys: String, CodingKey {
        case codec
        case sampleRate = "sample_rate"
        case bitDepth = "bit_depth"
        case bitrate
        case channels
    }
}
