// ABOUTME: HTTP HEAD request tester for stream URL accessibility
// ABOUTME: Returns status code, timing, and error information

import Foundation

public struct TestResult: Sendable {
    public let url: URL
    public let statusCode: Int?
    public let responseTime: TimeInterval
    public let error: Error?

    public var isAccessible: Bool {
        guard let code = statusCode else { return false }
        return (200 ... 299).contains(code)
    }
}

public actor URLTester {
    private let session: URLSession
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 5.0) {
        self.timeout = timeout

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.httpMaximumConnectionsPerHost = 1
        session = URLSession(configuration: config)
    }

    public func test(url: URL) async -> TestResult {
        let startTime = Date()

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout

        do {
            let (_, response) = try await session.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let responseTime = Date().timeIntervalSince(startTime)

            return TestResult(
                url: url,
                statusCode: httpResponse?.statusCode,
                responseTime: responseTime,
                error: nil
            )
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return TestResult(
                url: url,
                statusCode: nil,
                responseTime: responseTime,
                error: error
            )
        }
    }
}
