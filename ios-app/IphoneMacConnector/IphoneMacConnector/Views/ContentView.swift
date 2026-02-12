import SwiftUI

struct ContentView: View {
    @StateObject private var webSocketService = WebSocketService()
    @StateObject private var outputManager = TerminalOutputManager()

    @State private var config = ConnectionConfig.load()
    @State private var showingSettings = false
    @State private var showingDisconnectAlert = false

    var body: some View {
        ZStack {
            if webSocketService.connectionState.isConnected {
                // Connected view - Terminal and input
                VStack(spacing: 0) {
                    // Status bar
                    statusBar

                    // Terminal output
                    TerminalView(outputManager: outputManager)

                    // Command input
                    CommandInputView(isConnected: .constant(webSocketService.connectionState.isConnected)) { command in
                        webSocketService.sendCommand(command)
                    }
                }
            } else {
                // Disconnected view - Settings
                ConnectionSettingsView(
                    config: $config,
                    isShowingSettings: $showingSettings,
                    onConnect: connectToServer
                )
            }
        }
        .sheet(isPresented: $showingSettings) {
            ConnectionSettingsView(
                config: $config,
                isShowingSettings: $showingSettings,
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
        webSocketService.onOutputReceived = { output in
            outputManager.appendOutput(output)
        }

        webSocketService.onErrorReceived = { error in
            outputManager.appendOutput("\n[ERROR] \(error)\n")
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

        outputManager.clear()
        webSocketService.connect(config: config)
    }

    private func disconnectFromServer() {
        webSocketService.disconnect()
    }

    private func clearOutput() {
        outputManager.clear()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
