import XCTest
@testable import IphoneMacConnector

final class ConnectionConfigTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear any existing configuration
        ConnectionConfig.clear()
    }

    override func tearDown() {
        // Clean up after each test
        ConnectionConfig.clear()
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let config = ConnectionConfig()

        XCTAssertEqual(config.host, "")
        XCTAssertEqual(config.port, 8765)
        XCTAssertEqual(config.token, "")
    }

    func testCustomInitialization() {
        let config = ConnectionConfig(
            host: "100.64.1.2",
            port: 9000,
            token: "test-token"
        )

        XCTAssertEqual(config.host, "100.64.1.2")
        XCTAssertEqual(config.port, 9000)
        XCTAssertEqual(config.token, "test-token")
    }

    // MARK: - Tailscale Host Validation Tests

    func testIsTailscaleHost_ValidTailscaleIP() {
        let config = ConnectionConfig(host: "100.64.1.2", port: 8765, token: "token")
        XCTAssertTrue(config.isTailscaleHost)
    }

    func testIsTailscaleHost_ValidMagicDNS() {
        let config = ConnectionConfig(host: "macbook.tailnet-name.ts.net", port: 8765, token: "token")
        XCTAssertTrue(config.isTailscaleHost)
    }

    func testIsTailscaleHost_InvalidLocalhost() {
        let config = ConnectionConfig(host: "127.0.0.1", port: 8765, token: "token")
        XCTAssertFalse(config.isTailscaleHost)
    }

    func testIsTailscaleHost_InvalidPrivateIP() {
        let config = ConnectionConfig(host: "192.168.1.1", port: 8765, token: "token")
        XCTAssertFalse(config.isTailscaleHost)
    }

    func testIsTailscaleHost_InvalidPublicDomain() {
        let config = ConnectionConfig(host: "example.com", port: 8765, token: "token")
        XCTAssertFalse(config.isTailscaleHost)
    }

    // MARK: - Validation Tests

    func testIsValid_ValidConfiguration() {
        let config = ConnectionConfig(
            host: "100.64.1.2",
            port: 8765,
            token: "valid-token"
        )
        XCTAssertTrue(config.isValid)
        XCTAssertNil(config.validationError)
    }

    func testIsValid_InvalidEmptyHost() {
        let config = ConnectionConfig(host: "", port: 8765, token: "token")
        XCTAssertFalse(config.isValid)
        XCTAssertEqual(config.validationError, "Host cannot be empty")
    }

    func testIsValid_InvalidNonTailscaleHost() {
        let config = ConnectionConfig(host: "192.168.1.1", port: 8765, token: "token")
        XCTAssertFalse(config.isValid)
        XCTAssertEqual(config.validationError, "Host must be a Tailscale IP (100.x.x.x) or MagicDNS hostname (.ts.net)")
    }

    func testIsValid_InvalidPortTooLow() {
        let config = ConnectionConfig(host: "100.64.1.2", port: 0, token: "token")
        XCTAssertFalse(config.isValid)
        XCTAssertEqual(config.validationError, "Port must be between 1 and 65535")
    }

    func testIsValid_InvalidPortTooHigh() {
        let config = ConnectionConfig(host: "100.64.1.2", port: 70000, token: "token")
        XCTAssertFalse(config.isValid)
        XCTAssertEqual(config.validationError, "Port must be between 1 and 65535")
    }

    func testIsValid_InvalidEmptyToken() {
        let config = ConnectionConfig(host: "100.64.1.2", port: 8765, token: "")
        XCTAssertFalse(config.isValid)
        XCTAssertEqual(config.validationError, "Token cannot be empty")
    }

    // MARK: - WebSocket URL Tests

    func testWebsocketURL_ValidConfiguration() {
        let config = ConnectionConfig(
            host: "100.64.1.2",
            port: 8765,
            token: "token"
        )

        let url = config.websocketURL
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "ws")
        XCTAssertEqual(url?.host, "100.64.1.2")
        XCTAssertEqual(url?.port, 8765)
        XCTAssertEqual(url?.path, "/terminal")
    }

    func testWebsocketURL_InvalidConfiguration() {
        let config = ConnectionConfig(host: "", port: 8765, token: "")
        XCTAssertNil(config.websocketURL)
    }

    // MARK: - Save and Load Tests

    func testSaveAndLoad() {
        let originalConfig = ConnectionConfig(
            host: "100.64.1.2",
            port: 9000,
            token: "test-token-123"
        )

        originalConfig.save()

        let loadedConfig = ConnectionConfig.load()
        XCTAssertEqual(loadedConfig.host, originalConfig.host)
        XCTAssertEqual(loadedConfig.port, originalConfig.port)
        XCTAssertEqual(loadedConfig.token, originalConfig.token)
    }

    func testClear() {
        let config = ConnectionConfig(
            host: "100.64.1.2",
            port: 9000,
            token: "test-token"
        )
        config.save()

        ConnectionConfig.clear()

        let loadedConfig = ConnectionConfig.load()
        XCTAssertEqual(loadedConfig.host, "")
        XCTAssertEqual(loadedConfig.token, "")
    }
}
