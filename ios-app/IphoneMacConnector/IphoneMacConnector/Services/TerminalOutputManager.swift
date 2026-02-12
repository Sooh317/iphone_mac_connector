import Foundation
import Combine

class TerminalOutputManager: ObservableObject {
    @Published var outputText: String = ""
    @Published var lineCount: Int = 0

    private let maxLines = 10000
    private var lines: [String] = []
    private let lock = NSLock()

    /// Append output to the terminal
    func appendOutput(_ text: String) {
        lock.lock()
        defer { lock.unlock() }

        let strippedText = stripANSIEscapeSequences(text)
        let newLines = strippedText.components(separatedBy: .newlines)

        for line in newLines {
            if lines.count >= maxLines {
                // Remove oldest line
                lines.removeFirst()
            }
            lines.append(line)
        }

        let newCount = lines.count
        let newOutput = lines.joined(separator: "\n")

        // Update published properties on main thread
        DispatchQueue.main.async {
            self.lineCount = newCount
            self.outputText = newOutput
        }
    }

    /// Clear all output
    func clear() {
        lock.lock()
        defer { lock.unlock() }

        lines.removeAll()

        // Update published properties on main thread
        DispatchQueue.main.async {
            self.lineCount = 0
            self.outputText = ""
        }
    }

    /// Strip ANSI escape sequences from text
    /// Basic implementation for MVP - handles most common sequences
    private func stripANSIEscapeSequences(_ text: String) -> String {
        // Pattern matches:
        // - ESC[ followed by any number of parameters and a letter (CSI sequences)
        // - ESC followed by any character (other escape sequences)
        let ansiPattern = "\\u{001B}\\[[0-9;]*[A-Za-z]|\\u{001B}."

        guard let regex = try? NSRegularExpression(pattern: ansiPattern, options: []) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    /// Get the last N lines
    func getLastLines(_ count: Int) -> String {
        lock.lock()
        defer { lock.unlock() }

        let startIndex = max(0, lines.count - count)
        let lastLines = Array(lines[startIndex...])
        return lastLines.joined(separator: "\n")
    }

    /// Get all output
    func getAllOutput() -> String {
        lock.lock()
        defer { lock.unlock() }

        return lines.joined(separator: "\n")
    }

    /// Check if output contains specific text
    func contains(_ searchText: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return lines.contains { $0.contains(searchText) }
    }
}
