// ABOUTME: Unit tests for ConnectionState enum and its computed properties
// ABOUTME: Tests state machine logic without network dependencies

import Foundation
@testable import MusicAssistantKit
import Testing

@Suite("ConnectionState Unit Tests")
struct ConnectionStateTests {

    @Test("isConnected returns true when state is connected")
    func isConnectedWhenConnected() {
        let serverInfo = ServerInfo(
            serverVersion: "1.0.0",
            schemaVersion: 1,
            minSupportedSchemaVersion: 1,
            serverId: "test-server",
            homeassistantAddon: false,
            capabilities: [],
            baseUrl: "http://test",
            onboardDone: true
        )
        let state = ConnectionState.connected(serverInfo: serverInfo)

        #expect(state.isConnected == true)
    }

    @Test("isConnected returns false when state is disconnected")
    func isConnectedWhenDisconnected() {
        let state = ConnectionState.disconnected

        #expect(state.isConnected == false)
    }

    @Test("isConnected returns false when state is connecting")
    func isConnectedWhenConnecting() {
        let state = ConnectionState.connecting

        #expect(state.isConnected == false)
    }

    @Test("isConnected returns false when state is reconnecting")
    func isConnectedWhenReconnecting() {
        let state = ConnectionState.reconnecting(attempt: 1, delay: 1.0)

        #expect(state.isConnected == false)
    }

    @Test("isDisconnected returns true when state is disconnected")
    func isDisconnectedWhenDisconnected() {
        let state = ConnectionState.disconnected

        #expect(state.isDisconnected == true)
    }

    @Test("isDisconnected returns false when state is connected")
    func isDisconnectedWhenConnected() {
        let serverInfo = ServerInfo(
            serverVersion: "1.0.0",
            schemaVersion: 1,
            minSupportedSchemaVersion: 1,
            serverId: "test-server",
            homeassistantAddon: false,
            capabilities: [],
            baseUrl: "http://test",
            onboardDone: true
        )
        let state = ConnectionState.connected(serverInfo: serverInfo)

        #expect(state.isDisconnected == false)
    }

    @Test("isDisconnected returns false when state is connecting")
    func isDisconnectedWhenConnecting() {
        let state = ConnectionState.connecting

        #expect(state.isDisconnected == false)
    }

    @Test("isReconnecting returns true when state is reconnecting")
    func isReconnectingWhenReconnecting() {
        let state = ConnectionState.reconnecting(attempt: 2, delay: 4.0)

        #expect(state.isReconnecting == true)
    }

    @Test("isReconnecting returns false when state is connected")
    func isReconnectingWhenConnected() {
        let serverInfo = ServerInfo(
            serverVersion: "1.0.0",
            schemaVersion: 1,
            minSupportedSchemaVersion: 1,
            serverId: "test-server",
            homeassistantAddon: false,
            capabilities: [],
            baseUrl: "http://test",
            onboardDone: true
        )
        let state = ConnectionState.connected(serverInfo: serverInfo)

        #expect(state.isReconnecting == false)
    }

    @Test("isReconnecting returns false when state is disconnected")
    func isReconnectingWhenDisconnected() {
        let state = ConnectionState.disconnected

        #expect(state.isReconnecting == false)
    }
}
