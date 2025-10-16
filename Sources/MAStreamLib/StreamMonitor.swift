// ABOUTME: Monitors BUILTIN_PLAYER events and extracts stream URLs
// ABOUTME: Provides AsyncStream of stream information for consumption

@preconcurrency import Combine
import Foundation
import MusicAssistantKit

public struct StreamInfo: Sendable {
    public let event: BuiltinPlayerEvent
    public let url: String
    public let testResult: TestResult?
}

public actor StreamMonitor {
    private let client: MusicAssistantClient
    private let urlTester: URLTester?

    public init(client: MusicAssistantClient, testURLs: Bool = true, timeout: TimeInterval = 5.0) {
        self.client = client
        urlTester = testURLs ? URLTester(timeout: timeout) : nil
    }

    public nonisolated var streamEvents: AsyncStream<StreamInfo> {
        let client = client
        let urlTester = urlTester

        return AsyncStream { continuation in
            Task {
                let events = await client.events

                // Store cancellable to keep subscription alive
                let cancellable = events.builtinPlayerEvents.sink { event in
                    Task {
                        await Self.handleEvent(event, client: client, urlTester: urlTester, continuation: continuation)
                    }
                }

                // Set up termination handler to clean up the subscription
                continuation.onTermination = { @Sendable _ in
                    cancellable.cancel()
                }

                // Keep the task alive indefinitely by suspending
                await withTaskCancellationHandler {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
                    }
                } onCancel: {
                    cancellable.cancel()
                }
            }
        }
    }

    private static func handleEvent(
        _ event: BuiltinPlayerEvent,
        client: MusicAssistantClient,
        urlTester: URLTester?,
        continuation: AsyncStream<StreamInfo>.Continuation
    ) async {
        guard event.command == .playMedia,
              let mediaUrl = event.mediaUrl else {
            return
        }

        do {
            let streamURL = try await client.getStreamURL(mediaPath: mediaUrl)

            var testResult: TestResult?
            if let tester = urlTester {
                testResult = await tester.test(url: streamURL.url)
            }

            let info = StreamInfo(
                event: event,
                url: streamURL.url.absoluteString,
                testResult: testResult
            )

            continuation.yield(info)
        } catch {
            // Skip events we can't process
            return
        }
    }
}
