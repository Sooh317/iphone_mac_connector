import XCTest
@testable import IphoneMacConnector

final class KeychainServiceTests: XCTestCase {

    let testToken = "test-token-12345-abcdef"

    override func setUp() {
        super.setUp()
        // Clear keychain before each test
        KeychainService.shared.deleteToken()
    }

    override func tearDown() {
        // Clean up after each test
        KeychainService.shared.deleteToken()
        super.tearDown()
    }

    // MARK: - Save Token Tests

    func testSaveToken_Success() {
        KeychainService.shared.saveToken(testToken)

        let retrievedToken = KeychainService.shared.getToken()
        XCTAssertEqual(retrievedToken, testToken)
    }

    func testSaveToken_OverwriteExisting() {
        // Save first token
        KeychainService.shared.saveToken("first-token")

        // Save second token (should overwrite)
        KeychainService.shared.saveToken(testToken)

        let retrievedToken = KeychainService.shared.getToken()
        XCTAssertEqual(retrievedToken, testToken)
        XCTAssertNotEqual(retrievedToken, "first-token")
    }

    func testSaveToken_EmptyString() {
        KeychainService.shared.saveToken("")

        // Empty token should not be saved or should be saved as empty
        let retrievedToken = KeychainService.shared.getToken()
        // Depending on implementation, this might be nil or empty
        XCTAssertTrue(retrievedToken == nil || retrievedToken == "")
    }

    // MARK: - Get Token Tests

    func testGetToken_WhenExists() {
        KeychainService.shared.saveToken(testToken)

        let retrievedToken = KeychainService.shared.getToken()
        XCTAssertNotNil(retrievedToken)
        XCTAssertEqual(retrievedToken, testToken)
    }

    func testGetToken_WhenNotExists() {
        let retrievedToken = KeychainService.shared.getToken()
        XCTAssertNil(retrievedToken)
    }

    // MARK: - Delete Token Tests

    func testDeleteToken_WhenExists() {
        KeychainService.shared.saveToken(testToken)

        KeychainService.shared.deleteToken()

        let retrievedToken = KeychainService.shared.getToken()
        XCTAssertNil(retrievedToken)
    }

    func testDeleteToken_WhenNotExists() {
        // Should not crash when deleting non-existent token
        KeychainService.shared.deleteToken()

        let retrievedToken = KeychainService.shared.getToken()
        XCTAssertNil(retrievedToken)
    }

    // MARK: - Token Persistence Tests

    func testTokenPersistence() {
        KeychainService.shared.saveToken(testToken)

        // Simulate app restart by getting a fresh instance
        // (In real tests, KeychainService.shared is a singleton, so we just verify it persists)
        let retrievedToken = KeychainService.shared.getToken()
        XCTAssertEqual(retrievedToken, testToken)
    }

    // MARK: - Special Characters Tests

    func testSaveToken_WithSpecialCharacters() {
        let specialToken = "token-with-!@#$%^&*()_+-=[]{}|;:',.<>?/~`"
        KeychainService.shared.saveToken(specialToken)

        let retrievedToken = KeychainService.shared.getToken()
        XCTAssertEqual(retrievedToken, specialToken)
    }

    func testSaveToken_WithUnicode() {
        let unicodeToken = "token-with-émojis-🔐🔑"
        KeychainService.shared.saveToken(unicodeToken)

        let retrievedToken = KeychainService.shared.getToken()
        XCTAssertEqual(retrievedToken, unicodeToken)
    }

    // MARK: - Long Token Tests

    func testSaveToken_VeryLong() {
        let longToken = String(repeating: "a", count: 1000)
        KeychainService.shared.saveToken(longToken)

        let retrievedToken = KeychainService.shared.getToken()
        XCTAssertEqual(retrievedToken, longToken)
    }
}
