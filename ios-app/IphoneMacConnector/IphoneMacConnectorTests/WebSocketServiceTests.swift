import XCTest
import Combine
@testable import IphoneMacConnector

final class WebSocketServiceTests: XCTestCase {

    var service: WebSocketService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        service = WebSocketService()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        service.disconnect()
        service = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertEqual(service.connectionState.description, "Disconnected")
        XCTAssertNil(service.lastError)
    }

    // MARK: - Connection State Tests

    func testConnect_InvalidURL() {
        let invalidConfig = ConnectionConfig(host: "", port: 0, token: "")

        let expectation = XCTestExpectation(description: "Connection fails")

        service.$connectionState
            .sink { state in
                if case .error = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        service.connect(config: invalidConfig)

        wait(for: [expectation], timeout: 3.0)
    }

    func testConnect_ValidConfig_NoServer() {
        // This will attempt to connect but fail because no server is running
        let config = ConnectionConfig(
            host: "100.127.255.254", // Valid Tailscale IP but no server
            port: 8765,
            token: "test-token"
        )

        let expectation = XCTestExpectation(description: "Connection fails")

        service.$connectionState
            .sink { state in
                if case .error = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        service.connect(config: config)

        wait(for: [expectation], timeout: 5.0)
    }

    func testDisconnect_WhenConnecting() {
        let config = ConnectionConfig(
            host: "100.127.255.254",
            port: 8765,
            token: "test-token"
        )

        service.connect(config: config)

        // Immediately disconnect
        service.disconnect()

        // Wait a moment to ensure state updates
        let expectation = XCTestExpectation(description: "Disconnected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.service.connectionState.description, "Disconnected")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Message Sending Tests (when disconnected)

    func testSendCommand_WhenDisconnected() {
        // Should not crash when sending while disconnected
        service.sendCommand("test")

        // Verify still disconnected
        XCTAssertEqual(service.connectionState.description, "Disconnected")
    }

    func testSendResize_WhenDisconnected() {
        // Should not crash when sending resize while disconnected
        service.sendResize(cols: 80, rows: 24)

        // Verify still disconnected
        XCTAssertEqual(service.connectionState.description, "Disconnected")
    }

    // MARK: - Message Decoding Tests

    func testReceiveMessage_OutputCallback() {
        // Test WSMessage JSON decoding (pure unit test)
        let json = "{\"type\":\"output\",\"data\":\"test output\"}"

        if let data = json.data(using: .utf8),
           let message = try? JSONDecoder().decode(WSMessage.self, from: data) {
            XCTAssertEqual(message.type, .output)
            XCTAssertEqual(message.data, "test output")
        } else {
            XCTFail("Failed to decode WSMessage")
        }
    }

    // MARK: - Connection State Publisher Tests

    func testConnectionStatePublisher() {
        let expectation = XCTestExpectation(description: "State changes published")
        var stateChanges: [String] = []

        service.$connectionState
            .map { $0.description }
            .sink { state in
                stateChanges.append(state)
                if stateChanges.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Trigger state change
        let config = ConnectionConfig(
            host: "100.127.255.254",
            port: 8765,
            token: "test-token"
        )
        service.connect(config: config)

        wait(for: [expectation], timeout: 5.0)

        XCTAssertGreaterThan(stateChanges.count, 1)
    }

    // MARK: - Error Handling Tests

    func testLastError_UpdatesOnConnectionFailure() {
        let config = ConnectionConfig(
            host: "100.127.255.254",
            port: 8765,
            token: "test-token"
        )

        let expectation = XCTestExpectation(description: "Error set")

        service.$lastError
            .sink { error in
                if error != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        service.connect(config: config)

        wait(for: [expectation], timeout: 5.0)

        XCTAssertNotNil(service.lastError)
    }

    // MARK: - Cleanup Tests

    func testDisconnect_CleansUpResources() {
        let config = ConnectionConfig(
            host: "100.127.255.254",
            port: 8765,
            token: "test-token"
        )

        service.connect(config: config)
        service.disconnect()

        // Wait for cleanup
        let expectation = XCTestExpectation(description: "Resources cleaned")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.service.connectionState.description, "Disconnected")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Reconnection Tests

    func testMultipleConnectDisconnectCycles() {
        let config = ConnectionConfig(
            host: "100.127.255.254",
            port: 8765,
            token: "test-token"
        )

        for _ in 0..<3 {
            service.connect(config: config)
            Thread.sleep(forTimeInterval: 0.5)
            service.disconnect()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Should be disconnected after final disconnect
        XCTAssertEqual(service.connectionState.description, "Disconnected")
    }
}
