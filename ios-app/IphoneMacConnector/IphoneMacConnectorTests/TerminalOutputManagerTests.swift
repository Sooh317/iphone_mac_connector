import XCTest
import Combine
@testable import IphoneMacConnector

final class TerminalOutputManagerTests: XCTestCase {

    var manager: TerminalOutputManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        manager = TerminalOutputManager()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        manager = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Append Output Tests

    func testAppendOutput_BasicText() {
        let expectation = XCTestExpectation(description: "Output updated")

        manager.$outputText
            .dropFirst() // Skip initial empty value
            .sink { text in
                XCTAssertTrue(text.contains("Hello"))
                expectation.fulfill()
            }
            .store(in: &cancellables)

        manager.appendOutput("Hello")

        wait(for: [expectation], timeout: 2.0)
    }

    func testAppendOutput_MultipleLines() {
        let multilineText = "Line 1\nLine 2\nLine 3"

        manager.appendOutput(multilineText)

        // Wait for async update
        let expectation = XCTestExpectation(description: "Lines counted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.manager.lineCount, 3)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAppendOutput_ANSIStripping() {
        let textWithANSI = "\u{001B}[32mGreen text\u{001B}[0m"

        manager.appendOutput(textWithANSI)

        let expectation = XCTestExpectation(description: "ANSI stripped")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertTrue(self.manager.outputText.contains("Green text"))
            XCTAssertFalse(self.manager.outputText.contains("\u{001B}"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAppendOutput_MaxLinesLimit() {
        // Append more than maxLines (10000)
        for i in 0..<10500 {
            manager.appendOutput("Line \(i)")
        }

        let expectation = XCTestExpectation(description: "Max lines enforced")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertLessThanOrEqual(self.manager.lineCount, 10000)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Clear Tests

    func testClear() {
        manager.appendOutput("Some text")

        let expectation = XCTestExpectation(description: "Cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.manager.clear()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                XCTAssertEqual(self.manager.outputText, "")
                XCTAssertEqual(self.manager.lineCount, 0)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Get Last Lines Tests

    func testGetLastLines() {
        manager.appendOutput("Line 1\nLine 2\nLine 3\nLine 4\nLine 5")

        // Wait for processing
        let expectation = XCTestExpectation(description: "Lines processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let lastThree = self.manager.getLastLines(3)
            XCTAssertTrue(lastThree.contains("Line 3"))
            XCTAssertTrue(lastThree.contains("Line 4"))
            XCTAssertTrue(lastThree.contains("Line 5"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testGetLastLines_RequestMoreThanAvailable() {
        manager.appendOutput("Line 1\nLine 2")

        let expectation = XCTestExpectation(description: "Lines processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let lines = self.manager.getLastLines(10)
            // Should return all available lines
            XCTAssertTrue(lines.contains("Line 1"))
            XCTAssertTrue(lines.contains("Line 2"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Get All Output Tests

    func testGetAllOutput() {
        manager.appendOutput("First\nSecond\nThird")

        let expectation = XCTestExpectation(description: "All output retrieved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let allOutput = self.manager.getAllOutput()
            XCTAssertTrue(allOutput.contains("First"))
            XCTAssertTrue(allOutput.contains("Second"))
            XCTAssertTrue(allOutput.contains("Third"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Contains Tests

    func testContains_Found() {
        manager.appendOutput("This is a test message")

        let expectation = XCTestExpectation(description: "Text found")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertTrue(self.manager.contains("test message"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testContains_NotFound() {
        manager.appendOutput("This is a test message")

        let expectation = XCTestExpectation(description: "Text not found")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(self.manager.contains("nonexistent"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Thread Safety Tests

    func testThreadSafety_ConcurrentAppends() {
        let expectation = XCTestExpectation(description: "Concurrent appends completed")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for i in 0..<100 {
            queue.async {
                self.manager.appendOutput("Message \(i)")
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Should complete without crashing
            XCTAssertGreaterThan(self.manager.lineCount, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Publisher Tests

    func testPublisher_LineCountUpdates() {
        let expectation = XCTestExpectation(description: "Line count published")

        manager.$lineCount
            .dropFirst() // Skip initial 0
            .sink { count in
                XCTAssertGreaterThan(count, 0)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        manager.appendOutput("Test line")

        wait(for: [expectation], timeout: 2.0)
    }

    func testPublisher_OutputTextUpdates() {
        let expectation = XCTestExpectation(description: "Output text published")

        manager.$outputText
            .dropFirst() // Skip initial empty
            .sink { text in
                XCTAssertFalse(text.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        manager.appendOutput("Test output")

        wait(for: [expectation], timeout: 2.0)
    }
}
