import Foundation

enum MessageType: String, Codable {
    case input
    case output
    case resize
    case error
    case heartbeat
}

struct WSMessage: Codable {
    let type: MessageType
    let data: String?
    let message: String?
    let cols: Int?
    let rows: Int?
    let ts: Int64?

    init(type: MessageType, data: String? = nil, message: String? = nil, cols: Int? = nil, rows: Int? = nil) {
        self.type = type
        self.data = data
        self.message = message
        self.cols = cols
        self.rows = rows
        self.ts = type == .heartbeat ? Int64(Date().timeIntervalSince1970 * 1000) : nil
    }

    /// Encodes the message to JSON string for sending over WebSocket
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys

        guard let jsonData = try? encoder.encode(self) else {
            return nil
        }

        return String(data: jsonData, encoding: .utf8)
    }

    /// Decodes a JSON string into a WSMessage
    static func fromJSON(_ jsonString: String) -> WSMessage? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        return try? decoder.decode(WSMessage.self, from: jsonData)
    }
}
