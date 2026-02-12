import SwiftUI
import UIKit
import SwiftTerm
import AudioToolbox

@MainActor
final class TerminalSession: ObservableObject {
    private weak var terminalView: SwiftTerm.TerminalView?
    private var pendingOutput: [String] = []
    private let maxPendingChunks = 2000
    private var recentEscapeSequenceTail = ""
    private let alternateScreenExitSequences = [
        "\u{001B}[?1049l",
        "\u{001B}[?1047l",
        "\u{001B}[?47l"
    ]
    private let autoWrapDisableSequence = "\u{001B}[?7l"
    private let forceEnableAutoWrapSequence = "\u{001B}[?7h"
    // Keep less than the longest marker length so we only detect new markers.
    private let sequenceDetectionTailLength = 7

    func attach(terminalView: SwiftTerm.TerminalView) {
        self.terminalView = terminalView
        flushPendingOutput()
        _ = terminalView.becomeFirstResponder()
    }

    func detach(terminalView: SwiftTerm.TerminalView) {
        if self.terminalView === terminalView {
            self.terminalView = nil
        }
    }

    func feed(output: String, onTerminalStateRecoveryNeeded: (() -> Void)? = nil) {
        guard !output.isEmpty else { return }
        let (sanitizedOutput, requiresRecovery) = sanitizeOutput(output)

        guard let terminalView else {
            pendingOutput.append(sanitizedOutput)
            if pendingOutput.count > maxPendingChunks {
                pendingOutput.removeFirst(pendingOutput.count - maxPendingChunks)
            }
            if requiresRecovery {
                onTerminalStateRecoveryNeeded?()
            }
            return
        }

        terminalView.feed(text: sanitizedOutput)
        if requiresRecovery {
            onTerminalStateRecoveryNeeded?()
        }
    }

    func clearScreen() {
        pendingOutput.removeAll(keepingCapacity: true)
        terminalView?.feed(text: "\u{001B}[2J\u{001B}[3J\u{001B}[H")
    }

    func resetTerminal() {
        pendingOutput.removeAll(keepingCapacity: true)
        terminalView?.feed(text: "\u{001B}c")
    }

    private func flushPendingOutput() {
        guard let terminalView, !pendingOutput.isEmpty else { return }

        for chunk in pendingOutput {
            terminalView.feed(text: chunk)
        }
        pendingOutput.removeAll(keepingCapacity: true)
    }

    private func sanitizeOutput(_ output: String) -> (output: String, requiresRecovery: Bool) {
        let combined = recentEscapeSequenceTail + output
        let boundaryIndex = combined.index(combined.startIndex, offsetBy: recentEscapeSequenceTail.count)
        var detectedAlternateScreenExit = false
        var detectedAutoWrapDisable = false

        for marker in alternateScreenExitSequences {
            var searchRangeStart = combined.startIndex
            while searchRangeStart < combined.endIndex,
                  let range = combined.range(of: marker, range: searchRangeStart..<combined.endIndex) {
                if range.upperBound > boundaryIndex {
                    detectedAlternateScreenExit = true
                    break
                }

                searchRangeStart = combined.index(after: range.lowerBound)
            }

            if detectedAlternateScreenExit {
                break
            }
        }

        var searchRangeStart = combined.startIndex
        while searchRangeStart < combined.endIndex,
              let range = combined.range(of: autoWrapDisableSequence, range: searchRangeStart..<combined.endIndex) {
            if range.upperBound > boundaryIndex {
                detectedAutoWrapDisable = true
                break
            }

            searchRangeStart = combined.index(after: range.lowerBound)
        }

        recentEscapeSequenceTail = String(combined.suffix(sequenceDetectionTailLength))

        if detectedAlternateScreenExit || detectedAutoWrapDisable {
            return (output + forceEnableAutoWrapSequence, true)
        }

        return (output, false)
    }
}

private final class NativeTerminalView: SwiftTerm.TerminalView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonSetup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonSetup()
    }

    private func commonSetup() {
        font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        backgroundColor = .black
        isOpaque = true
        nativeBackgroundColor = .black
        nativeForegroundColor = .green
        caretColor = .white
        optionAsMetaKey = true
        allowMouseReporting = true
        keyboardAppearance = .dark
        autocorrectionType = .no
        autocapitalizationType = .none
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            _ = becomeFirstResponder()
        }
    }
}

struct TerminalView: View {
    @ObservedObject var terminalSession: TerminalSession
    var onInput: (String) -> Void
    var onResize: ((Int, Int) -> Void)? = nil

    var body: some View {
        TerminalContainerView(
            terminalSession: terminalSession,
            onInput: onInput,
            onResize: onResize
        )
        .background(Color.black)
        .ignoresSafeArea(edges: .horizontal)
    }
}

private struct TerminalContainerView: UIViewRepresentable {
    var terminalSession: TerminalSession
    var onInput: (String) -> Void
    var onResize: ((Int, Int) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            terminalSession: terminalSession,
            onInput: onInput,
            onResize: onResize
        )
    }

    func makeUIView(context: Context) -> NativeTerminalView {
        let terminalView = NativeTerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator
        context.coordinator.bind(to: terminalView)
        return terminalView
    }

    func updateUIView(_ uiView: NativeTerminalView, context: Context) {
        context.coordinator.bind(to: uiView)
    }

    static func dismantleUIView(_ uiView: NativeTerminalView, coordinator: Coordinator) {
        coordinator.unbind(from: uiView)
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        private let terminalSession: TerminalSession
        private let onInput: (String) -> Void
        private let onResize: ((Int, Int) -> Void)?
        private var pendingResizeWorkItem: DispatchWorkItem?
        private let resizeDebounceInterval: TimeInterval = 0.12
        private let minimumTerminalCols = 30
        private let minimumTerminalRows = 10

        init(
            terminalSession: TerminalSession,
            onInput: @escaping (String) -> Void,
            onResize: ((Int, Int) -> Void)?
        ) {
            self.terminalSession = terminalSession
            self.onInput = onInput
            self.onResize = onResize
        }

        @MainActor
        func bind(to terminalView: SwiftTerm.TerminalView) {
            terminalSession.attach(terminalView: terminalView)
        }

        @MainActor
        func unbind(from terminalView: SwiftTerm.TerminalView) {
            terminalSession.detach(terminalView: terminalView)
        }

        func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
            guard newCols >= minimumTerminalCols, newRows >= minimumTerminalRows else {
                return
            }

            pendingResizeWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.onResize?(newCols, newRows)
            }
            pendingResizeWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + resizeDebounceInterval, execute: workItem)
        }

        func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {
            // No-op for now.
        }

        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
            // No-op for now.
        }

        func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
            let text = String(decoding: data, as: UTF8.self)
            onInput(text)
        }

        func scrolled(source: SwiftTerm.TerminalView, position: Double) {
            // No-op for now.
        }

        func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String: String]) {
            guard let url = URL(string: link) else { return }
            UIApplication.shared.open(url)
        }

        func bell(source: SwiftTerm.TerminalView) {
            AudioServicesPlaySystemSound(1104)
        }

        func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {
            guard let text = String(data: content, encoding: .utf8) else { return }
            UIPasteboard.general.string = text
        }

        func iTermContent(source: SwiftTerm.TerminalView, content: ArraySlice<UInt8>) {
            // No-op for now.
        }

        func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {
            // No-op for now.
        }
    }
}

struct TerminalView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalView(
            terminalSession: TerminalSession(),
            onInput: { _ in },
            onResize: { _, _ in }
        )
    }
}
