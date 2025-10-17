// ABOUTME: Mock audio player for testing PlayerSession without AVFoundation
// ABOUTME: Tracks calls and provides controllable state

import AVFoundation
import Foundation
@testable import MAPlayerLib

@MainActor
public final class MockAudioPlayer: AudioPlayerProtocol {
    public var lastReplacedURL: URL?
    public var playCallCount = 0
    public var pauseCallCount = 0
    public var mockCurrentTime = CMTime.zero
    public var mockDuration: CMTime?
    public var mockRate: Float = 0.0

    public init() {}

    public func replaceCurrentItem(with url: URL?) {
        lastReplacedURL = url
    }

    public func play() {
        playCallCount += 1
        mockRate = 1.0
    }

    public func pause() {
        pauseCallCount += 1
        mockRate = 0.0
    }

    public func seek(to time: CMTime, toleranceBefore _: CMTime, toleranceAfter _: CMTime) async -> Bool {
        mockCurrentTime = time
        return true
    }

    public var currentTime: CMTime { mockCurrentTime }
    public var duration: CMTime? { mockDuration }
    public var rate: Float { mockRate }
}
