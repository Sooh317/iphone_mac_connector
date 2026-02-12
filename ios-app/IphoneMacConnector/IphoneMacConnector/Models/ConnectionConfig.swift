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

    var isTailscaleHost: Bool {
        // Check for Tailscale IP addresses (100.64.0.0/10 range)
        if host.hasPrefix("100.") {
            return true
        }
        // Check for Tailscale MagicDNS hostnames (.ts.net)
        if host.hasSuffix(".ts.net") {
            return true
        }
        return false
    }

    var isValid: Bool {
        !host.isEmpty && isTailscaleHost && port > 0 && port <= 65535 && !token.isEmpty
    }

    var validationError: String? {
        if host.isEmpty {
            return "Host cannot be empty"
        }
        if !isTailscaleHost {
            return "Host must be a Tailscale IP (100.x.x.x) or MagicDNS hostname (.ts.net)"
        }
        if port <= 0 || port > 65535 {
            return "Port must be between 1 and 65535"
        }
        if token.isEmpty {
            return "Token cannot be empty"
        }
        return nil
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
