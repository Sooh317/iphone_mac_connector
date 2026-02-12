import SwiftUI
import UIKit
import SwiftTerm
import AudioToolbox
import Foundation

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
    private let forceEnableAutoWrapSequence = "\u{001B}[?7h"
    private static let csiPrivateModeRegex = try! NSRegularExpression(
        pattern: "(?:\u{001B}\\[|\u{009B})\\?([0-9;]+)([hl])"
    )
    // Keep enough tail to detect split private-mode sequences such as ESC[?1;3;4;6l.
    private let sequenceDetectionTailLength = 24

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
        var removalRangesInOutput: [Range<Int>] = []
        var detectedSessionRestore = false

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

        let fullRange = NSRange(combined.startIndex..<combined.endIndex, in: combined)
        let privateModeMatches = Self.csiPrivateModeRegex.matches(in: combined, options: [], range: fullRange)
        for match in privateModeMatches {
            guard let sequenceRange = Range(match.range(at: 0), in: combined),
                  let paramsRange = Range(match.range(at: 1), in: combined),
                  let commandRange = Range(match.range(at: 2), in: combined) else {
                continue
            }
            guard sequenceRange.upperBound > boundaryIndex else { continue }

            let params = combined[paramsRange].split(separator: ";")
            let hasMode3 = params.contains { Int($0) == 3 }
            let hasMode7 = params.contains { Int($0) == 7 }
            let hasMode1004 = params.contains { Int($0) == 1004 }
            let hasMode2004 = params.contains { Int($0) == 2004 }
            let hasMode25 = params.contains { Int($0) == 25 }
            let command = combined[commandRange].first

            if hasMode3 {
                let startOffset = max(
                    0,
                    combined.distance(from: boundaryIndex, to: sequenceRange.lowerBound)
                )
                let endOffset = combined.distance(from: boundaryIndex, to: sequenceRange.upperBound)
                if endOffset > startOffset {
                    removalRangesInOutput.append(startOffset..<endOffset)
                }
            }

            if hasMode7 && command == "l" {
                detectedAutoWrapDisable = true
            }
            if (hasMode1004 || hasMode2004) && command == "l" {
                detectedSessionRestore = true
            }
            if hasMode25 && command == "h" {
                detectedSessionRestore = true
            }
        }

        recentEscapeSequenceTail = String(combined.suffix(sequenceDetectionTailLength))

        var sanitizedOutput = output
        if !removalRangesInOutput.isEmpty {
            let mergedRanges = mergeRanges(removalRangesInOutput)
            for range in mergedRanges.reversed() {
                let start = sanitizedOutput.index(sanitizedOutput.startIndex, offsetBy: range.lowerBound)
                let end = sanitizedOutput.index(sanitizedOutput.startIndex, offsetBy: range.upperBound)
                sanitizedOutput.removeSubrange(start..<end)
            }
        }

        if detectedAlternateScreenExit || detectedAutoWrapDisable || !removalRangesInOutput.isEmpty || detectedSessionRestore {
            return (sanitizedOutput + forceEnableAutoWrapSequence, true)
        }

        return (sanitizedOutput, false)
    }

    private func mergeRanges(_ ranges: [Range<Int>]) -> [Range<Int>] {
        guard !ranges.isEmpty else { return [] }
        let sorted = ranges.sorted { lhs, rhs in
            if lhs.lowerBound == rhs.lowerBound {
                return lhs.upperBound < rhs.upperBound
            }
            return lhs.lowerBound < rhs.lowerBound
        }

        var merged: [Range<Int>] = []
        for range in sorted {
            guard let last = merged.last else {
                merged.append(range)
                continue
            }

            if range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }

        return merged
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
