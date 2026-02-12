import SwiftUI
import UIKit

struct TerminalView: View {
    @ObservedObject var outputManager: TerminalOutputManager
    var onResize: ((Int, Int) -> Void)? = nil

    @State private var scrollProxy: ScrollViewProxy?
    @State private var shouldAutoScroll = true
    @State private var currentCols: Int = 80
    @State private var currentRows: Int = 24

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if outputManager.outputText.isEmpty {
                VStack {
                    Image(systemName: "terminal")
                        .font(.system(size: 60))
                        .foregroundColor(.green.opacity(0.3))
                    Text("Terminal Output")
                        .font(.title2)
                        .foregroundColor(.green.opacity(0.5))
                    Text("Connected - Waiting for output...")
                        .font(.caption)
                        .foregroundColor(.green.opacity(0.4))
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(outputManager.attributedOutput)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(nil)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("terminalBottom")
                        }
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                    .onChange(of: outputManager.outputText) { _ in
                        if shouldAutoScroll {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
            }

                // Auto-scroll toggle button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            shouldAutoScroll.toggle()
                            if shouldAutoScroll, let proxy = scrollProxy {
                                scrollToBottom(proxy: proxy)
                            }
                        }) {
                            Image(systemName: shouldAutoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                                .font(.title2)
                                .foregroundColor(shouldAutoScroll ? .green : .gray)
                                .padding(12)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                }
            }
            .onAppear {
                calculateTerminalSize(from: geometry.size)
            }
            .onChange(of: geometry.size) { newSize in
                calculateTerminalSize(from: newSize)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("terminalBottom", anchor: .bottom)
        }
    }

    private func calculateTerminalSize(from size: CGSize) {
        let font = UIFont.monospacedSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
            weight: .regular
        )
        let characterSize = ("W" as NSString).size(withAttributes: [.font: font])
        let charWidth = max(characterSize.width, 1.0)
        let charHeight = max(characterSize.height, 1.0)
        let horizontalPadding: CGFloat = 16.0
        let verticalPadding: CGFloat = 16.0

        let availableWidth = max(0, size.width - horizontalPadding)
        let availableHeight = max(0, size.height - verticalPadding)

        let newCols = max(20, Int(floor(availableWidth / charWidth)))
        let newRows = max(5, Int(floor(availableHeight / charHeight)))

        if newCols != currentCols {
            currentCols = newCols
            currentRows = newRows
            onResize?(newCols, newRows)
            return
        }

        currentRows = newRows
    }
}

struct TerminalView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalView(outputManager: TerminalOutputManager())
    }
}
