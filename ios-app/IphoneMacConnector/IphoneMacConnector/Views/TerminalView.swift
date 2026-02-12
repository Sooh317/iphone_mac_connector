import SwiftUI
import UIKit
import SwiftTerm
import AudioToolbox

@MainActor
final class TerminalSession: ObservableObject {
    private weak var terminalView: SwiftTerm.TerminalView?
    private var pendingOutput: [String] = []
    private let maxPendingChunks = 2000

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

    func feed(output: String) {
        guard !output.isEmpty else { return }

        guard let terminalView else {
            pendingOutput.append(output)
            if pendingOutput.count > maxPendingChunks {
                pendingOutput.removeFirst(pendingOutput.count - maxPendingChunks)
            }
            return
        }

        terminalView.feed(text: output)
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
            onResize?(newCols, newRows)
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
