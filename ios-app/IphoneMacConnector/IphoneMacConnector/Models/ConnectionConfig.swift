import Foundation

struct ConnectionConfig: Codable {
    var host: String
    var port: Int
    var token: String

    init(host: String = "", port: Int = 8765, token: String = "") {
        self.host = host
        self.port = port
        self.token = token
    }

    var isValid: Bool {
        !host.isEmpty && port > 0 && port <= 65535 && !token.isEmpty
    }

    var websocketURL: URL? {
        guard isValid else { return nil }

        // Support both IP addresses and hostnames
        let urlString = "ws://\(host):\(port)/terminal"
        return URL(string: urlString)
    }

    /// Load configuration from UserDefaults
    static func load() -> ConnectionConfig {
        let defaults = UserDefaults.standard
        let host = defaults.string(forKey: "connection.host") ?? ""
        let port = defaults.integer(forKey: "connection.port")
        let finalPort = port == 0 ? 8765 : port

        // Token is loaded separately from Keychain
        let token = KeychainService.shared.getToken() ?? ""

        return ConnectionConfig(host: host, port: finalPort, token: token)
    }

    /// Save configuration to UserDefaults and Keychain
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(host, forKey: "connection.host")
        defaults.set(port, forKey: "connection.port")

        // Save token to Keychain
        if !token.isEmpty {
            KeychainService.shared.saveToken(token)
        }
    }

    /// Clear configuration
    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "connection.host")
        defaults.removeObject(forKey: "connection.port")
        KeychainService.shared.deleteToken()
    }
}
