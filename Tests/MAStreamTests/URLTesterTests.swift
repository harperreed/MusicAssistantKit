// ABOUTME: Unit tests for URLTester HTTP accessibility checking
// ABOUTME: Validates HEAD requests, status code handling, and timeout behavior

@testable import MAStreamLib
import XCTest

final class URLTesterTests: XCTestCase {
    func testAccessibleURL() async throws {
        let tester = URLTester()

        guard let url = URL(string: "https://httpbin.org/status/200") else {
            XCTFail("Invalid URL")
            return
        }
        let result = await tester.test(url: url)

        XCTAssertEqual(result.statusCode, 200)
        XCTAssertTrue(result.isAccessible)
        XCTAssertGreaterThan(result.responseTime, 0)
    }

    func testInaccessibleURL() async throws {
        let tester = URLTester()

        guard let url = URL(string: "https://httpbin.org/status/404") else {
            XCTFail("Invalid URL")
            return
        }
        let result = await tester.test(url: url)

        XCTAssertEqual(result.statusCode, 404)
        XCTAssertFalse(result.isAccessible)
    }

    func testTimeout() async throws {
        let tester = URLTester(timeout: 0.1)

        guard let url = URL(string: "https://httpbin.org/delay/5") else {
            XCTFail("Invalid URL")
            return
        }
        let result = await tester.test(url: url)

        XCTAssertNil(result.statusCode)
        XCTAssertFalse(result.isAccessible)
        XCTAssertNotNil(result.error)
    }
}
