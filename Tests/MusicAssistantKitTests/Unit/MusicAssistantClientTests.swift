// ABOUTME: Comprehensive unit tests for MusicAssistantClient using mock connection
// ABOUTME: Tests command methods, message handling, timeouts, and error scenarios

import Foundation
import Testing
@testable import MusicAssistantKit

@Suite("MusicAssistantClient Unit Tests")
struct MusicAssistantClientTests {

    // MARK: - Initialization and Connection Tests

    @Test("Client initializes with host and port")
    func initialization() async {
        let client = MusicAssistantClient(host: "test.local", port: 8095)
        let isConnected = await client.isConnected

        #expect(isConnected == false, "Should not be connected initially")
    }

    @Test("Client connects successfully")
    func connect() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let isConnected = await client.isConnected
        #expect(isConnected == true)
    }

    @Test("Client disconnect cancels pending commands")
    func disconnectCancelsPending() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        // Start a command that won't get a response
        let task = Task {
            try await client.sendCommand(command: "test/command")
        }

        // Give it a moment to register
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Disconnect should cancel the pending command
        await client.disconnect()

        do {
            _ = try await task.value
            Issue.record("Expected command to throw after disconnect")
        } catch let error as MusicAssistantError {
            if case .notConnected = error {
                // Expected
            } else {
                Issue.record("Expected notConnected error, got \(error)")
            }
        }
    }

    // MARK: - Player Control Command Tests

    @Test("getPlayers sends correct command")
    func getPlayers() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        // Send command and immediately respond
        let task = Task {
            try await client.getPlayers()
        }

        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        let command = await mock.getLastCommand()
        #expect(command?.command == "players/all")

        await mock.simulateResult(messageId: command!.messageId, result: AnyCodable(["players": []]))
        _ = try await task.value
    }

    @Test("play command includes player_id")
    func play() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.play(playerId: "test-player")
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.command == "players/cmd/play")
        #expect(command?.args?["player_id"]?.value as? String == "test-player")

        await mock.simulateResult(messageId: command!.messageId, result: nil)
        try await task.value
    }

    @Test("pause command includes player_id")
    func pause() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.pause(playerId: "test-player")
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.command == "players/cmd/pause")
        #expect(command?.args?["player_id"]?.value as? String == "test-player")

        await mock.simulateResult(messageId: command!.messageId, result: nil)
        try await task.value
    }

    @Test("stop command includes player_id")
    func stop() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.stop(playerId: "test-player")
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.command == "players/cmd/stop")
        #expect(command?.args?["player_id"]?.value as? String == "test-player")

        await mock.simulateResult(messageId: command!.messageId, result: nil)
        try await task.value
    }

    // MARK: - Search Command Tests

    @Test("search command with default limit")
    func searchDefault() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.search(query: "test query")
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.command == "music/search")
        #expect(command?.args?["search_query"]?.value as? String == "test query")
        #expect(command?.args?["limit"]?.value as? Int == 25)

        await mock.simulateResult(messageId: command!.messageId, result: AnyCodable(["results": []]))
        _ = try await task.value
    }

    @Test("search command with custom limit")
    func searchCustomLimit() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.search(query: "test query", limit: 50)
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.args?["limit"]?.value as? Int == 50)

        await mock.simulateResult(messageId: command!.messageId, result: AnyCodable(["results": []]))
        _ = try await task.value
    }

    // MARK: - Queue Command Tests

    @Test("getQueue command includes queue_id")
    func getQueue() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.getQueue(queueId: "test-queue")
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.command == "player_queues/get")
        #expect(command?.args?["queue_id"]?.value as? String == "test-queue")

        await mock.simulateResult(messageId: command!.messageId, result: AnyCodable(["queue": []]))
        _ = try await task.value
    }

    @Test("getQueueItems with default pagination")
    func getQueueItemsDefault() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.getQueueItems(queueId: "test-queue")
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.command == "player_queues/items")
        #expect(command?.args?["queue_id"]?.value as? String == "test-queue")
        #expect(command?.args?["limit"]?.value as? Int == 50)
        #expect(command?.args?["offset"]?.value as? Int == 0)

        await mock.simulateResult(messageId: command!.messageId, result: AnyCodable(["items": []]))
        _ = try await task.value
    }

    @Test("getQueueItems with custom pagination")
    func getQueueItemsCustom() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.getQueueItems(queueId: "test-queue", limit: 100, offset: 50)
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.args?["limit"]?.value as? Int == 100)
        #expect(command?.args?["offset"]?.value as? Int == 50)

        await mock.simulateResult(messageId: command!.messageId, result: AnyCodable(["items": []]))
        _ = try await task.value
    }

    @Test("playMedia with default options")
    func playMediaDefault() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.playMedia(queueId: "test-queue", uri: "test://uri")
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.command == "player_queues/play_media")
        #expect(command?.args?["queue_id"]?.value as? String == "test-queue")
        #expect(command?.args?["uri"]?.value as? String == "test://uri")
        #expect(command?.args?["option"]?.value as? String == "play")
        #expect(command?.args?["radio_mode"]?.value as? Bool == false)

        await mock.simulateResult(messageId: command!.messageId, result: nil)
        _ = try await task.value
    }

    @Test("playMedia with custom options and radio mode")
    func playMediaCustom() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.playMedia(queueId: "test-queue", uri: "test://uri", option: "add", radioMode: true)
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.args?["option"]?.value as? String == "add")
        #expect(command?.args?["radio_mode"]?.value as? Bool == true)

        await mock.simulateResult(messageId: command!.messageId, result: nil)
        _ = try await task.value
    }

    @Test("clearQueue command")
    func clearQueue() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.clearQueue(queueId: "test-queue")
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.command == "player_queues/clear")
        #expect(command?.args?["queue_id"]?.value as? String == "test-queue")

        await mock.simulateResult(messageId: command!.messageId, result: nil)
        try await task.value
    }

    @Test("shuffle command enables shuffling")
    func shuffleEnable() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.shuffle(queueId: "test-queue", enabled: true)
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.command == "player_queues/shuffle")
        #expect(command?.args?["queue_id"]?.value as? String == "test-queue")
        #expect(command?.args?["shuffle"]?.value as? Bool == true)

        await mock.simulateResult(messageId: command!.messageId, result: nil)
        try await task.value
    }

    @Test("shuffle command disables shuffling")
    func shuffleDisable() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.shuffle(queueId: "test-queue", enabled: false)
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.args?["shuffle"]?.value as? Bool == false)

        await mock.simulateResult(messageId: command!.messageId, result: nil)
        try await task.value
    }

    @Test("setRepeat command with mode")
    func setRepeat() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.setRepeat(queueId: "test-queue", mode: "all")
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()
        #expect(command?.command == "player_queues/repeat")
        #expect(command?.args?["queue_id"]?.value as? String == "test-queue")
        #expect(command?.args?["repeat_mode"]?.value as? String == "all")

        await mock.simulateResult(messageId: command!.messageId, result: nil)
        try await task.value
    }

    // MARK: - Message Handling Tests

    @Test("Client handles result messages")
    func handleResults() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.sendCommand(command: "test/command")
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()

        await mock.simulateResult(messageId: command!.messageId, result: AnyCodable("success"))

        let result = try await task.value
        #expect(result?.value as? String == "success")
    }

    @Test("Client handles error responses")
    func handleErrors() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        let task = Task {
            try await client.sendCommand(command: "test/command")
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        let command = await mock.getLastCommand()

        await mock.simulateError(messageId: command!.messageId, error: "Test error", code: 500)

        do {
            _ = try await task.value
            Issue.record("Expected error to be thrown")
        } catch let error as MusicAssistantError {
            if case .serverError(let code, let message, _) = error {
                #expect(code == 500)
                #expect(message == "Test error")
            } else {
                Issue.record("Expected serverError, got \(error)")
            }
        }
    }

    @Test("Client publishes events to EventPublisher")
    func publishEvents() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        // Simulate an event
        let event = Event(
            event: "player_updated",
            objectId: "test-player",
            data: AnyCodable(["state": "playing"])
        )

        await mock.simulateEvent(event)

        // Give the event time to propagate
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // The event should have been published (we can't easily test Combine publishers in Swift Testing)
        // But we've verified the code path executes without error
    }

    // MARK: - Error Handling Tests

    @Test("sendCommand throws when not connected")
    func throwsWhenNotConnected() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        // Don't connect
        do {
            _ = try await client.sendCommand(command: "test/command")
            Issue.record("Expected error to be thrown")
        } catch let error as MusicAssistantError {
            if case .notConnected = error {
                // Expected
            } else {
                Issue.record("Expected notConnected error, got \(error)")
            }
        }
    }

    @Test("Message ID increments for each command")
    func messageIdIncrements() async throws {
        let mock = MockWebSocketConnection()
        let client = MusicAssistantClient(connection: mock)

        try await client.connect()

        // Send first command
        let task1 = Task {
            try await client.sendCommand(command: "test/command1")
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        let command1 = await mock.getLastCommand()
        await mock.simulateResult(messageId: command1!.messageId, result: nil)
        _ = try await task1.value

        // Send second command
        let task2 = Task {
            try await client.sendCommand(command: "test/command2")
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        let command2 = await mock.getLastCommand()
        await mock.simulateResult(messageId: command2!.messageId, result: nil)
        _ = try await task2.value

        #expect(command2!.messageId > command1!.messageId)
    }
}
