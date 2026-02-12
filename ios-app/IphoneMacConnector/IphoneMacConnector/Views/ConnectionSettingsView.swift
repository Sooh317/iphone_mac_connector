import SwiftUI

struct ConnectionSettingsView: View {
    @Binding var config: ConnectionConfig
    @Binding var isShowingSettings: Bool

    @State private var host: String = ""
    @State private var portString: String = ""
    @State private var token: String = ""
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""

    var onConnect: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Configuration")) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Tailscale IP or hostname", text: $host)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)

                        Text("Example: 100.x.y.z or macbook.ts.net")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("8765", text: $portString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                Section(header: Text("Authentication")) {
                    SecureField("Access Token", text: $token)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section(header: Text("Connection Status")) {
                    HStack {
                        Text("Configuration")
                        Spacer()
                        if isConfigValid {
                            Text("Valid")
                                .foregroundColor(.green)
                        } else {
                            Text("Invalid")
                                .foregroundColor(.red)
                        }
                    }

                    if let errorMessage = validationError {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: saveConfiguration) {
                        HStack {
                            Spacer()
                            Text("Save Configuration")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isConfigValid)

                    Button(action: connectToServer) {
                        HStack {
                            Spacer()
                            Text("Connect")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled(!isConfigValid)
                    .buttonStyle(.borderedProminent)
                }

                Section {
                    Button(action: loadSavedConfiguration) {
                        HStack {
                            Spacer()
                            Text("Load Saved Configuration")
                            Spacer()
                        }
                    }

                    Button(role: .destructive, action: clearConfiguration) {
                        HStack {
                            Spacer()
                            Text("Clear Configuration")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Connection Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isShowingSettings {
                        Button("Done") {
                            isShowingSettings = false
                        }
                    }
                }
            }
            .alert("Configuration", isPresented: $showingSaveAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveAlertMessage)
            }
            .onAppear {
                loadCurrentConfig()
            }
        }
    }

    private var isConfigValid: Bool {
        let tempConfig = ConnectionConfig(
            host: host.trimmingCharacters(in: .whitespaces),
            port: portNumber,
            token: token.trimmingCharacters(in: .whitespaces)
        )
        return tempConfig.isValid
    }

    private var validationError: String? {
        let tempConfig = ConnectionConfig(
            host: host.trimmingCharacters(in: .whitespaces),
            port: portNumber,
            token: token.trimmingCharacters(in: .whitespaces)
        )
        return tempConfig.validationError
    }

    private var portNumber: Int {
        Int(portString) ?? 0
    }

    private func loadCurrentConfig() {
        host = config.host
        portString = config.port > 0 ? "\(config.port)" : "8765"
        token = config.token
    }

    private func saveConfiguration() {
        let newConfig = ConnectionConfig(
            host: host.trimmingCharacters(in: .whitespaces),
            port: portNumber,
            token: token.trimmingCharacters(in: .whitespaces)
        )

        newConfig.save()
        config = newConfig

        saveAlertMessage = "Configuration saved successfully"
        showingSaveAlert = true
    }

    private func connectToServer() {
        config = ConnectionConfig(
            host: host.trimmingCharacters(in: .whitespaces),
            port: portNumber,
            token: token.trimmingCharacters(in: .whitespaces)
        )

        onConnect()

        if isShowingSettings {
            isShowingSettings = false
        }
    }

    private func loadSavedConfiguration() {
        let savedConfig = ConnectionConfig.load()
        host = savedConfig.host
        portString = savedConfig.port > 0 ? "\(savedConfig.port)" : "8765"
        token = savedConfig.token

        config = savedConfig

        saveAlertMessage = "Configuration loaded from storage"
        showingSaveAlert = true
    }

    private func clearConfiguration() {
        ConnectionConfig.clear()
        host = ""
        portString = "8765"
        token = ""

        config = ConnectionConfig()

        saveAlertMessage = "Configuration cleared"
        showingSaveAlert = true
    }
}

struct ConnectionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionSettingsView(
            config: .constant(ConnectionConfig()),
            isShowingSettings: .constant(false),
            onConnect: {}
        )
    }
}
