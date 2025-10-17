// ABOUTME: Formats stream events and test results for console or JSON output
// ABOUTME: Supports ANSI colors and JSON mode for scripting

import Foundation
import MusicAssistantKit

public struct OutputFormatter {
    private let jsonMode: Bool
    private let colorEnabled: Bool

    public init(jsonMode: Bool, colorEnabled: Bool) {
        self.jsonMode = jsonMode
        self.colorEnabled = colorEnabled
    }

    public func formatStreamEvent(_ event: BuiltinPlayerEvent, streamURL: String) -> String {
        if jsonMode {
            formatJSON(event: event, streamURL: streamURL)
        } else {
            formatText(event: event, streamURL: streamURL)
        }
    }

    public func formatTestResult(_ result: TestResult) -> String {
        if jsonMode {
            formatJSON(result: result)
        } else {
            formatText(result: result)
        }
    }

    private func formatText(event: BuiltinPlayerEvent, streamURL: String) -> String {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let command = color(event.command.rawValue, .blue)

        var output = """

        [\(timestamp)] \(command) event received
        """

        if let queueId = event.queueId {
            output += "\n  Queue: \(queueId)"
        }

        if let itemId = event.queueItemId {
            output += "\n  Item:  \(itemId)"
        }

        output += """


          Stream URL:
          \(streamURL)

        """

        // Parse format from URL
        if let format = extractFormat(from: streamURL) {
            output += "  Format: \(format)\n"
        }

        // Parse mode (flow/single)
        if streamURL.contains("/flow/") {
            output += "  Mode:   flow (gapless)\n"
        } else if streamURL.contains("/single/") {
            output += "  Mode:   single\n"
        }

        return output
    }

    private func formatText(result: TestResult) -> String {
        if result.isAccessible, let statusCode = result.statusCode {
            let status = color("✓ Accessible", .green)
            return "  Status: \(status) (\(statusCode) OK)\n"
        } else if let error = result.error {
            let status = color("✗ Error", .red)
            return "  Status: \(status) (\(error.localizedDescription))\n"
        } else {
            let status = color("✗ Failed", .red)
            return "  Status: \(status) (\(result.statusCode ?? 0))\n"
        }
    }

    private func formatJSON(event: BuiltinPlayerEvent, streamURL: String) -> String {
        let dict: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "command": event.command.rawValue,
            "stream_url": streamURL,
            "queue_id": event.queueId as Any,
            "queue_item_id": event.queueItemId as Any,
            "format": extractFormat(from: streamURL) as Any,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private func formatJSON(result: TestResult) -> String {
        let dict: [String: Any] = [
            "url": result.url.absoluteString,
            "status_code": result.statusCode as Any,
            "response_time": result.responseTime,
            "accessible": result.isAccessible,
            "error": result.error?.localizedDescription as Any,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private func extractFormat(from url: String) -> String? {
        let components = url.split(separator: ".")
        return components.last.map(String.init)
    }

    private func color(_ text: String, _ code: ANSIColor) -> String {
        guard colorEnabled else { return text }
        return "\u{001B}[\(code.rawValue)m\(text)\u{001B}[0m"
    }

    private enum ANSIColor: Int {
        case red = 31
        case green = 32
        case blue = 34
    }
}
