import SwiftUI

struct ContentView: View {
    @StateObject private var webSocketService = WebSocketService()
    @StateObject private var terminalSession = TerminalSession()

    @State private var config = ConnectionConfig.load()
    @State private var showingSettings = false
    @State private var showingDisconnectAlert = false
    @State private var showingTokenImportAlert = false
    @State private var tokenImportMessage = ""

    var body: some View {
        ZStack {
            if webSocketService.connectionState.isConnected {
                // Connected view - Terminal
                VStack(spacing: 0) {
                    // Status bar
                    statusBar

                    // Terminal output
                    TerminalView(
                        terminalSession: terminalSession,
                        onInput: { data in
                            webSocketService.sendCommand(data)
                            if data.contains("\n") || data.contains("\r") {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                    webSocketService.resendLastResize()
                                }
                            }
                        },
                        onResize: { cols, rows in
                            webSocketService.sendResize(cols: cols, rows: rows)
                        }
                    )

                }
            } else {
                // Disconnected view - Settings
                ConnectionSettingsView(
                    config: $config,
                    isShowingSettings: $showingSettings,
                    connectionState: webSocketService.connectionState,
                    lastError: webSocketService.lastError,
                    onConnect: connectToServer
                )
            }
        }
        .sheet(isPresented: $showingSettings) {
            ConnectionSettingsView(
                config: $config,
                isShowingSettings: $showingSettings,
                connectionState: webSocketService.connectionState,
                lastError: webSocketService.lastError,
                onConnect: connectToServer
            )
        }
        .alert("Disconnect", isPresented: $showingDisconnectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                disconnectFromServer()
            }
        } message: {
            Text("Are you sure you want to disconnect from the server?")
        }
        .alert("Token Import", isPresented: $showingTokenImportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(tokenImportMessage)
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onAppear {
            setupWebSocketCallbacks()
        }
    }

    private var statusBar: some View {
        HStack {
            // Connection indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 12, height: 12)

                Text(webSocketService.connectionState.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 16) {
                // New terminal session button
                Button(action: createNewTerminalSession) {
                    Image(systemName: "plus.rectangle.on.rectangle")
                        .font(.title3)
                        .foregroundColor(.green)
                }

                // Clear output button
                Button(action: clearOutput) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.red)
                }

                // Settings button
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.blue)
                }

                // Disconnect button
                Button(action: {
                    showingDisconnectAlert = true
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }

    private var connectionColor: Color {
        switch webSocketService.connectionState {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }

    private func setupWebSocketCallbacks() {
        let service = webSocketService
        let session = terminalSession

        webSocketService.onOutputReceived = { [weak service] output in
            session.feed(output: output) {
                service?.resendLastResize()
            }
        }

        webSocketService.onErrorReceived = { error in
            terminalSession.feed(output: "\r\n[ERROR] \(error)\r\n")
        }

        webSocketService.onMessageReceived = { message in
            // Handle other message types if needed
            print("Received message: \(message.type)")
        }
    }

    private func connectToServer() {
        guard config.isValid else {
            print("Invalid configuration")
            return
        }

        terminalSession.resetTerminal()
        webSocketService.connect(config: config)
    }

    private func disconnectFromServer() {
        webSocketService.disconnect()
    }

    private func clearOutput() {
        terminalSession.clearScreen()
    }

    private func createNewTerminalSession() {
        terminalSession.resetTerminal()
        webSocketService.restartTerminalSession()
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "iphonemacconnector",
              url.host == "import-token",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return
        }

        KeychainService.shared.saveToken(token)
        config.token = token
        showingSettings = true
        tokenImportMessage = "Token imported from QR. Review settings and tap Connect."
        showingTokenImportAlert = true
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
