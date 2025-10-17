// ABOUTME: Protocol for audio playback, enabling AVPlayer mocking in tests
// ABOUTME: Provides standard playback controls and state observation

import AVFoundation
import Foundation

@MainActor
public protocol AudioPlayerProtocol: Sendable {
    func replaceCurrentItem(with url: URL?)
    func play()
    func pause()
    func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime) async -> Bool
    var currentTime: CMTime { get }
    var duration: CMTime? { get }
    var rate: Float { get }
}

extension AVPlayer: AudioPlayerProtocol {
    public var duration: CMTime? {
        currentItem?.duration
    }

    public var currentTime: CMTime {
        currentTime()
    }

    public func replaceCurrentItem(with url: URL?) {
        if let url {
            replaceCurrentItem(with: AVPlayerItem(url: url))
        } else {
            replaceCurrentItem(with: nil as AVPlayerItem?)
        }
    }
}
