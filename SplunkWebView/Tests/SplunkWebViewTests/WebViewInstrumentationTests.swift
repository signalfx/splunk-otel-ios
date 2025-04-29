import XCTest
import WebKit
@testable import SplunkWebView

final class WebViewInstrumentationTests: XCTestCase {

    var webViewInstrumentation: WebViewInstrumentation!
    var mockWebView: MockWebView!

    override func setUp() {
        super.setUp()
        webViewInstrumentation = WebViewInstrumentation()
        mockWebView = MockWebView()
        webViewInstrumentation.sharedState = MockAgentSharedState() // Provide a mock shared state
    }

    override func tearDown() {
        webViewInstrumentation = nil
        mockWebView = nil
        super.tearDown()
    }

    func testInjectSessionId() {
        let expectation = XCTestExpectation(description: "JavaScript injected")

        mockWebView.evaluateJavaScriptHandler = { (script, completionHandler) in
            // Assert that the script is the expected script
            XCTAssertTrue(script.contains("window.SplunkRumNative"))
            XCTAssertTrue(script.contains("getNativeSessionId"))
            XCTAssertTrue(script.contains("cachedSessionId"))
            expectation.fulfill()
            completionHandler(nil, nil) // Simulate success
        }

        webViewInstrumentation.injectSessionId(into: mockWebView)

        wait(for: [expectation], timeout: 1.0)
    }

    // Add more tests here to cover error cases, etc.
}

// Mock WKWebView for testing
class MockWebView: WKWebView {
    var evaluateJavaScriptHandler: ((String, @escaping (Any?, Error?) -> Void) -> Void)?

    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        evaluateJavaScriptHandler?(javaScriptString, completionHandler ?? { _, _ in })
    }
}

class MockAgentSharedState: AgentSharedState {
    var sessionId: String? = "test-session-id"
}
