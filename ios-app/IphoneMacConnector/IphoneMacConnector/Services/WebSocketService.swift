import Foundation
import Combine

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case error(String)

    var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

class WebSocketService: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: String?

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var config: ConnectionConfig?
    private var heartbeatTimer: Timer?
    private var reconnectTimer: Timer?
    private var shouldReconnect = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    // Callbacks
    var onMessageReceived: ((WSMessage) -> Void)?
    var onOutputReceived: ((String) -> Void)?
    var onErrorReceived: ((String) -> Void)?

    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    /// Connect to WebSocket server
    func connect(config: ConnectionConfig) {
        guard config.isValid else {
            connectionState = .error("Invalid configuration")
            return
        }

        guard let url = config.websocketURL else {
            connectionState = .error("Invalid WebSocket URL")
            return
        }

        self.config = config
        shouldReconnect = true
        reconnectAttempts = 0

        performConnection(url: url, token: config.token)
    }

    private func performConnection(url: URL, token: String) {
        connectionState = .connecting

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()

        // Start receiving messages
        receiveMessage()

        // Start heartbeat timer
        startHeartbeat()

        print("WebSocketService: Connecting to \(url.absoluteString)")
    }

    /// Disconnect from WebSocket server
    func disconnect() {
        shouldReconnect = false
        stopHeartbeat()
        stopReconnectTimer()

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        connectionState = .disconnected
        print("WebSocketService: Disconnected")
    }

    /// Send a message to the server
    func sendMessage(_ message: WSMessage) {
        guard connectionState.isConnected else {
            print("WebSocketService: Cannot send message - not connected")
            return
        }

        guard let jsonString = message.toJSON() else {
            print("WebSocketService: Failed to encode message")
            return
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)

        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                print("WebSocketService: Send error - \(error.localizedDescription)")
                self?.handleError(error)
            }
        }
    }

    /// Send command input to the server
    func sendCommand(_ command: String) {
        let message = WSMessage(type: .input, data: command)
        sendMessage(message)
    }

    /// Send terminal resize message
    func sendResize(cols: Int, rows: Int) {
        let message = WSMessage(type: .resize, cols: cols, rows: rows)
        sendMessage(message)
    }

    /// Send heartbeat message
    private func sendHeartbeat() {
        let message = WSMessage(type: .heartbeat)
        sendMessage(message)
    }

    /// Receive messages from the server
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleReceivedMessage(message)
                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
                print("WebSocketService: Receive error - \(error.localizedDescription)")
                self.handleError(error)
            }
        }
    }

    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            if let wsMessage = WSMessage.fromJSON(text) {
                DispatchQueue.main.async {
                    self.onMessageReceived?(wsMessage)

                    switch wsMessage.type {
                    case .output:
                        if let data = wsMessage.data {
                            self.onOutputReceived?(data)
                        }
                    case .error:
                        if let errorMsg = wsMessage.message {
                            self.onErrorReceived?(errorMsg)
                            self.lastError = errorMsg
                        }
                    case .heartbeat:
                        // Heartbeat acknowledged
                        break
                    default:
                        break
                    }
                }
            }

        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                print("WebSocketService: Received binary data as text: \(text)")
            }

        @unknown default:
            print("WebSocketService: Unknown message type")
        }
    }

    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.connectionState = .error(error.localizedDescription)
            self.lastError = error.localizedDescription
        }

        stopHeartbeat()

        // Attempt reconnection if needed
        if shouldReconnect && reconnectAttempts < maxReconnectAttempts {
            attemptReconnection()
        } else {
            disconnect()
        }
    }

    private func attemptReconnection() {
        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts) * 2.0, 30.0) // Exponential backoff, max 30s

        print("WebSocketService: Reconnection attempt \(reconnectAttempts)/\(maxReconnectAttempts) in \(delay)s")

        stopReconnectTimer()

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, let config = self.config, let url = config.websocketURL else {
                return
            }

            print("WebSocketService: Attempting to reconnect...")
            self.performConnection(url: url, token: config.token)
        }
    }

    private func startHeartbeat() {
        stopHeartbeat()

        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    deinit {
        disconnect()
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocketService: Connection opened")
        reconnectAttempts = 0

        DispatchQueue.main.async {
            self.connectionState = .connected
            self.lastError = nil
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        var reasonString = "Unknown"
        if let reason = reason, let reasonText = String(data: reason, encoding: .utf8) {
            reasonString = reasonText
        }

        print("WebSocketService: Connection closed - Code: \(closeCode.rawValue), Reason: \(reasonString)")

        stopHeartbeat()

        DispatchQueue.main.async {
            if self.shouldReconnect && self.reconnectAttempts < self.maxReconnectAttempts {
                self.connectionState = .connecting
                self.attemptReconnection()
            } else {
                self.connectionState = .disconnected
            }
        }
    }
}
