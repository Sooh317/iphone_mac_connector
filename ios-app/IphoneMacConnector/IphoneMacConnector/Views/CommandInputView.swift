import SwiftUI

struct CommandInputView: View {
    @Binding var isConnected: Bool
    @State private var commandText: String = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int = -1
    @State private var showingHistory = false

    var onSendCommand: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // History view
            if showingHistory && !commandHistory.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Command History")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: clearHistory) {
                                Text("Clear")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        Divider()

                        ForEach(Array(commandHistory.enumerated().reversed()), id: \.offset) { index, command in
                            Button(action: {
                                commandText = command
                                showingHistory = false
                            }) {
                                HStack {
                                    Text(command)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "arrow.up.circle")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)

                            if index != 0 {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }

            // Command input bar
            HStack(spacing: 12) {
                // History button
                Button(action: {
                    showingHistory.toggle()
                }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundColor(commandHistory.isEmpty ? .gray : .blue)
                        .frame(width: 44, height: 44)
                }
                .disabled(commandHistory.isEmpty)

                // Command input field
                TextField("Enter command...", text: $commandText, onCommit: sendCommand)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(.body, design: .monospaced))
                    .disabled(!isConnected)

                // Send button
                Button(action: sendCommand) {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundColor(canSend ? .blue : .gray)
                        .frame(width: 44, height: 44)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.3)),
                alignment: .top
            )
        }
    }

    private var canSend: Bool {
        isConnected && !commandText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func sendCommand() {
        guard canSend else { return }

        let command = commandText.trimmingCharacters(in: .whitespaces)

        // Add to history if not empty and not duplicate of last command
        if !command.isEmpty && (commandHistory.isEmpty || commandHistory.last != command) {
            commandHistory.append(command)

            // Limit history to 50 commands
            if commandHistory.count > 50 {
                commandHistory.removeFirst()
            }
        }

        // Send the command
        onSendCommand(command + "\n") // Add newline for terminal

        // Clear input and reset history index
        commandText = ""
        historyIndex = -1
        showingHistory = false
    }

    private func clearHistory() {
        commandHistory.removeAll()
        historyIndex = -1
        showingHistory = false
    }

    private func navigateHistory(direction: Int) {
        guard !commandHistory.isEmpty else { return }

        if historyIndex == -1 {
            historyIndex = commandHistory.count - 1
        } else {
            historyIndex += direction
            historyIndex = max(0, min(commandHistory.count - 1, historyIndex))
        }

        if historyIndex >= 0 && historyIndex < commandHistory.count {
            commandText = commandHistory[historyIndex]
        }
    }
}

struct CommandInputView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            CommandInputView(isConnected: .constant(true)) { command in
                print("Command: \(command)")
            }
        }
    }
}
