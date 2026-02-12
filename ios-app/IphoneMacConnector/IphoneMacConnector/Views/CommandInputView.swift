import SwiftUI
import AVFoundation
import Speech

struct CommandInputView: View {
    @Binding var isConnected: Bool
    @State private var commandText: String = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int = -1
    @State private var showingHistory = false
    @StateObject private var voiceInputController = VoiceInputController()
    @State private var showingVoiceError = false
    @State private var voiceErrorMessage = ""

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

                // Voice input button
                Button(action: toggleVoiceInput) {
                    Image(systemName: voiceInputController.isRecording ? "mic.fill" : "mic")
                        .font(.title3)
                        .foregroundColor(voiceButtonColor)
                        .frame(width: 44, height: 44)
                }
                .disabled(!isConnected)

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
        .alert("Voice Input", isPresented: $showingVoiceError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(voiceErrorMessage)
        }
        .onDisappear {
            voiceInputController.stopRecording()
        }
    }

    private var canSend: Bool {
        isConnected && !commandText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var voiceButtonColor: Color {
        if !isConnected {
            return .gray
        }
        return voiceInputController.isRecording ? .red : .blue
    }

    private func sendCommand() {
        guard canSend else { return }

        if voiceInputController.isRecording {
            voiceInputController.stopRecording()
        }

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

    private func toggleVoiceInput() {
        if voiceInputController.isRecording {
            voiceInputController.stopRecording()
            return
        }

        voiceInputController.startRecording(
            onResult: { transcript in
                commandText = transcript
            },
            onError: { message in
                voiceErrorMessage = message
                showingVoiceError = true
            }
        )
    }
}

@MainActor
final class VoiceInputController: ObservableObject {
    @Published private(set) var isRecording = false

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale.current)
        ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func startRecording(onResult: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        requestPermissions { [weak self] granted, message in
            guard let self else { return }

            guard granted else {
                onError(message ?? "Speech recognition permission was denied.")
                return
            }

            beginRecognition(onResult: onResult, onError: onError)
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        isRecording = false

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func beginRecognition(onResult: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            onError("Speech recognizer is not available right now.")
            return
        }

        stopRecording()

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if #available(iOS 16.0, *) {
                request.addsPunctuation = true
            }
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                Task { @MainActor in
                    if let result {
                        onResult(result.bestTranscription.formattedString)
                        if result.isFinal {
                            self.stopRecording()
                        }
                    }

                    if let error, self.isRecording {
                        self.stopRecording()
                        onError("Failed to recognize speech: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            stopRecording()
            onError("Failed to start voice input: \(error.localizedDescription)")
        }
    }

    private func requestPermissions(completion: @escaping (Bool, String?) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                switch status {
                case .authorized:
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        Task { @MainActor in
                            if granted {
                                completion(true, nil)
                            } else {
                                completion(false, "Microphone access is required for voice input.")
                            }
                        }
                    }
                case .denied:
                    completion(false, "Speech recognition access was denied. Enable it in Settings.")
                case .restricted:
                    completion(false, "Speech recognition is restricted on this device.")
                case .notDetermined:
                    completion(false, "Speech recognition permission is not determined yet.")
                @unknown default:
                    completion(false, "Speech recognition is unavailable.")
                }
            }
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
