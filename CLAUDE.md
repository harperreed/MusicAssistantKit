# MusicAssistantKit Project Guide

## Testing Strategy

**EXCEPTION TO GLOBAL RULES**: This project uses mock implementations for testing.

This project requires mocking because:
- We need to test client logic without network dependencies
- WebSocket connections cannot be reliably used in unit tests
- We need controllable, deterministic test scenarios

### Mocking Guidelines

1. **Mock objects are ONLY for testing** - they live in the `Tests/` directory
2. **Mocks implement protocols** - use `WebSocketConnectionProtocol` and similar interfaces
3. **Keep mocks simple** - they should be straightforward test doubles, not complex implementations
4. **Use mocks to verify behavior** - track sent commands, simulate responses, control timing

### Existing Mocks

- `MockWebSocketConnection` - provides controllable WebSocket behavior for unit tests

When adding new mocks:
- Follow the existing pattern in `Tests/MusicAssistantKitTests/Mocks/`
- Ensure they conform to the appropriate protocol
- Add test helpers for common scenarios (simulating errors, results, events)
- Document what the mock is for and how to use it

## Testing Requirements

All tests must pass with pristine output before committing. This includes:
- Unit tests
- Integration tests (when `SKIP_INTEGRATION_TESTS` is not set)
- SwiftLint validation
- SwiftFormat validation

## Running Tests

### Quick Test Run (Unit Tests Only)
```bash
# Skip integration tests that require a live server
SKIP_INTEGRATION_TESTS=1 swift test
```
76 unit tests will run using mocks. This is the default for CI/CD.

### Full Test Run (Unit + Integration)
```bash
# Run against your local Music Assistant server
MA_TEST_HOST=localhost MA_TEST_PORT=8095 swift test
```
All 77 tests will run (76 with mocks + 1 integration test against real server).

### Custom Server Configuration
```bash
# Point to a different Music Assistant instance
MA_TEST_HOST=music-assistant.local MA_TEST_PORT=8095 swift test
```

## Test Architecture

This project uses a **dual-mode testing strategy**:

1. **Unit Tests (76 tests)** - Use `MockWebSocketConnection`
   - Fast (< 1 second)
   - No external dependencies
   - Test client logic in isolation
   - Located in: `Tests/MusicAssistantKitTests/Unit/`

2. **Integration Tests (1 test)** - Use real `WebSocketConnection`
   - Validate against real Music Assistant server
   - Skippable via `SKIP_INTEGRATION_TESTS` env var
   - Configurable via `MA_TEST_HOST` and `MA_TEST_PORT`
   - Located in: `Tests/MusicAssistantKitTests/Integration/`

### Why This Works

The project uses **protocol-based dependency injection**:
- `WebSocketConnectionProtocol` defines the interface
- `MockWebSocketConnection` implements it for tests
- `WebSocketConnection` implements it for production
- `MusicAssistantClient` accepts either via internal initializer

This allows comprehensive unit testing without network dependencies while maintaining the ability to validate against real servers.
