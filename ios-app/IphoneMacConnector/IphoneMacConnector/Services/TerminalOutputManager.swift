import Foundation
import Combine
import SwiftUI

class TerminalOutputManager: ObservableObject {
    @Published var outputText: String = ""
    @Published var attributedOutput: AttributedString = AttributedString()
    @Published var lineCount: Int = 0

    private let maxLines = 10000
    private var rawBuffer: String = ""
    private let lock = NSLock()

    /// Append output to the terminal
    func appendOutput(_ text: String) {
        lock.lock()
        defer { lock.unlock() }

        rawBuffer.append(normalizeLineEndings(text))
        trimRawBufferToMaxLines()

        let parsed = parseTerminalOutput(rawBuffer)
        let newCount = countLines(in: parsed.plain)

        // Update published properties on main thread
        DispatchQueue.main.async {
            self.lineCount = newCount
            self.outputText = parsed.plain
            self.attributedOutput = parsed.attributed
        }
    }

    /// Clear all output
    func clear() {
        lock.lock()
        defer { lock.unlock() }

        rawBuffer.removeAll()

        // Update published properties on main thread
        DispatchQueue.main.async {
            self.lineCount = 0
            self.outputText = ""
            self.attributedOutput = AttributedString()
        }
    }

    private struct ANSIStyle {
        var foregroundCode: Int = 32
    }

    private struct StyledGlyph {
        let character: Character
        let foregroundCode: Int
    }

    private struct ParsedTerminalOutput {
        let attributed: AttributedString
        let plain: String
    }

    private func parseTerminalOutput(_ text: String) -> ParsedTerminalOutput {
        var lines: [[StyledGlyph]] = [[]]
        var cursorColumn = 0
        var style = ANSIStyle()
        var index = text.startIndex

        func writeCharacter(_ character: Character) {
            let glyph = StyledGlyph(character: character, foregroundCode: style.foregroundCode)
            let lastLineIndex = lines.count - 1

            if cursorColumn < lines[lastLineIndex].count {
                lines[lastLineIndex][cursorColumn] = glyph
            } else {
                while lines[lastLineIndex].count < cursorColumn {
                    lines[lastLineIndex].append(StyledGlyph(character: " ", foregroundCode: style.foregroundCode))
                }
                lines[lastLineIndex].append(glyph)
            }

            cursorColumn += 1
        }

        func appendNewline() {
            lines.append([])
            cursorColumn = 0
        }

        func appendStyledRun(_ text: String, foregroundCode: Int, to attributed: inout AttributedString) {
            guard !text.isEmpty else { return }

            var segment = AttributedString(text)
            segment.font = .system(.body, design: .monospaced)
            segment.foregroundColor = ansiColor(for: foregroundCode)
            attributed.append(segment)
        }

        func renderedOutput(from lines: [[StyledGlyph]]) -> ParsedTerminalOutput {
            var plain = ""
            var attributed = AttributedString()

            for lineIndex in lines.indices {
                let line = lines[lineIndex]

                if !line.isEmpty {
                    plain.append(contentsOf: line.map(\.character))

                    var runText = ""
                    var currentColorCode = line[0].foregroundCode

                    for glyph in line {
                        if glyph.foregroundCode != currentColorCode {
                            appendStyledRun(runText, foregroundCode: currentColorCode, to: &attributed)
                            runText.removeAll(keepingCapacity: true)
                            currentColorCode = glyph.foregroundCode
                        }
                        runText.append(glyph.character)
                    }

                    appendStyledRun(runText, foregroundCode: currentColorCode, to: &attributed)
                }

                if lineIndex < lines.count - 1 {
                    plain.append("\n")
                    appendStyledRun("\n", foregroundCode: style.foregroundCode, to: &attributed)
                }
            }

            return ParsedTerminalOutput(attributed: attributed, plain: plain)
        }

        while index < text.endIndex {
            let character = text[index]

            if character == "\u{001B}" {
                let nextIndex = text.index(after: index)
                guard nextIndex < text.endIndex else { break }

                if text[nextIndex] == "[" {
                    var cursor = text.index(after: nextIndex)
                    var parameters = ""
                    var finalByte: Character?

                    while cursor < text.endIndex {
                        let value = text[cursor]

                        if isCSIFinalByte(value) {
                            finalByte = value
                            cursor = text.index(after: cursor)
                            break
                        }

                        parameters.append(value)
                        cursor = text.index(after: cursor)
                    }

                    guard let finalByte else { break }
                    if finalByte == "m" {
                        applyANSICodes(parameters, style: &style)
                    }

                    index = cursor
                    continue
                }

                if text[nextIndex] == "]" {
                    var cursor = text.index(after: nextIndex)
                    var isTerminated = false

                    while cursor < text.endIndex {
                        let value = text[cursor]

                        if value == "\u{0007}" {
                            cursor = text.index(after: cursor)
                            isTerminated = true
                            break
                        }

                        if value == "\u{001B}" {
                            let stIndex = text.index(after: cursor)
                            if stIndex < text.endIndex && text[stIndex] == "\\" {
                                cursor = text.index(after: stIndex)
                                isTerminated = true
                                break
                            }
                        }

                        cursor = text.index(after: cursor)
                    }

                    guard isTerminated else { break }
                    index = cursor
                    continue
                }

                // Unhandled ESC sequence: consume ESC and next character.
                index = text.index(after: nextIndex)
                continue
            }

            if character == "\n" {
                appendNewline()
                index = text.index(after: index)
                continue
            }

            if character == "\r" {
                cursorColumn = 0
                index = text.index(after: index)
                continue
            }

            if character == "\t" {
                let spacesToNextTabStop = 4 - (cursorColumn % 4)
                for _ in 0..<spacesToNextTabStop {
                    writeCharacter(" ")
                }
                index = text.index(after: index)
                continue
            }

            if character == "\u{0008}" {
                cursorColumn = max(0, cursorColumn - 1)
                index = text.index(after: index)
                continue
            }

            if shouldSkipControlCharacter(character) {
                index = text.index(after: index)
                continue
            }

            writeCharacter(character)
            index = text.index(after: index)
        }

        return renderedOutput(from: lines)
    }

    private func isCSIFinalByte(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first,
              character.unicodeScalars.count == 1 else {
            return false
        }

        return scalar.value >= 0x40 && scalar.value <= 0x7E
    }

    private func shouldSkipControlCharacter(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first,
              character.unicodeScalars.count == 1 else {
            return false
        }

        if character == "\n" || character == "\t" {
            return false
        }

        if character == "\r" || character == "\u{0008}" {
            return false
        }

        return scalar.value < 0x20 || scalar.value == 0x7F
    }

    private func trimRawBufferToMaxLines() {
        let lines = rawBuffer.split(separator: "\n", omittingEmptySubsequences: false)

        guard lines.count > maxLines else { return }
        rawBuffer = lines.suffix(maxLines).joined(separator: "\n")
    }

    private func countLines(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return text.reduce(into: 1) { count, char in
            if char == "\n" {
                count += 1
            }
        }
    }

    private func applyANSICodes(_ parameterString: String, style: inout ANSIStyle) {
        let codes = parameterString
            .split(separator: ";")
            .compactMap { Int($0) }

        let normalizedCodes = codes.isEmpty ? [0] : codes

        for code in normalizedCodes {
            switch code {
            case 0:
                style = ANSIStyle()
            case 39:
                style.foregroundCode = ANSIStyle().foregroundCode
            case 30...37, 90...97:
                style.foregroundCode = code
            default:
                continue
            }
        }
    }

    private func ansiColor(for code: Int) -> Color {
        switch code {
        case 30: return .black
        case 31: return .red
        case 32: return .green
        case 33: return .yellow
        case 34: return .blue
        case 35: return .purple
        case 36: return .cyan
        case 37: return .white
        case 90: return .gray
        case 91: return .red.opacity(0.85)
        case 92: return .green.opacity(0.85)
        case 93: return .yellow.opacity(0.85)
        case 94: return .blue.opacity(0.85)
        case 95: return .purple.opacity(0.85)
        case 96: return .cyan.opacity(0.85)
        case 97: return .white
        default: return .green
        }
    }

    private func normalizeLineEndings(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
    }

    /// Get the last N lines
    func getLastLines(_ count: Int) -> String {
        lock.lock()
        defer { lock.unlock() }

        guard count > 0 else { return "" }

        let plain = parseTerminalOutput(rawBuffer).plain
        guard !plain.isEmpty else { return "" }

        let plainLines = plain.components(separatedBy: "\n")
        let startIndex = max(0, plainLines.count - count)
        let lastLines = Array(plainLines[startIndex...])
        return lastLines.joined(separator: "\n")
    }

    /// Get all output
    func getAllOutput() -> String {
        lock.lock()
        defer { lock.unlock() }

        return parseTerminalOutput(rawBuffer).plain
    }

    /// Check if output contains specific text
    func contains(_ searchText: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return parseTerminalOutput(rawBuffer).plain.contains(searchText)
    }
}
