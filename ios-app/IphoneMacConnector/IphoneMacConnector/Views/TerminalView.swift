import SwiftUI

struct TerminalView: View {
    @ObservedObject var outputManager: TerminalOutputManager

    @State private var scrollProxy: ScrollViewProxy?
    @State private var shouldAutoScroll = true

    var body: some View {
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
                            Text(outputManager.outputText)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.green)
                                .textSelection(.enabled)
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
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("terminalBottom", anchor: .bottom)
        }
    }
}

struct TerminalView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalView(outputManager: TerminalOutputManager())
    }
}
