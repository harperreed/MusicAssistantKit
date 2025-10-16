// ABOUTME: Unit tests for URLTester HTTP accessibility checking
// ABOUTME: Validates HEAD requests, status code handling, and timeout behavior

import XCTest
@testable import MAStream

final class URLTesterTests: XCTestCase {
    func testAccessibleURL() async throws {
        let tester = URLTester()

        let result = await tester.test(url: URL(string: "https://httpbin.org/status/200")!)

        XCTAssertEqual(result.statusCode, 200)
        XCTAssertTrue(result.isAccessible)
        XCTAssertGreaterThan(result.responseTime, 0)
    }

    func testInaccessibleURL() async throws {
        let tester = URLTester()

        let result = await tester.test(url: URL(string: "https://httpbin.org/status/404")!)

        XCTAssertEqual(result.statusCode, 404)
        XCTAssertFalse(result.isAccessible)
    }

    func testTimeout() async throws {
        let tester = URLTester(timeout: 0.1)

        let result = await tester.test(url: URL(string: "https://httpbin.org/delay/5")!)

        XCTAssertNil(result.statusCode)
        XCTAssertFalse(result.isAccessible)
        XCTAssertNotNil(result.error)
    }
}
