import XCTest
import WebKit
@testable import SplunkWebViewProxy
import SplunkWebView

final class WebViewInstrumentationProxyTests: XCTestCase {

    var webViewInstrumentationProxy: WebViewInstrumentationProxy!
    var mockWebViewInstrumentation: MockWebViewInstrumentation!
    var mockWebView: WKWebView!

    override func setUp() {
        super.setUp()
        mockWebViewInstrumentation = MockWebViewInstrumentation()
        webViewInstrumentationProxy = WebViewInstrumentationProxy()
        mockWebView = WKWebView()
    }

    override func tearDown() {
        webViewInstrumentationProxy = nil
        mockWebViewInstrumentation = nil
        mockWebView = nil
        super.tearDown()
    }

    func testInjectSessionId() {
        //ARRANGE
        mockWebViewInstrumentation.injectSessionIdCalled = false
        //ACT
        webViewInstrumentationProxy.injectSessionId(into: mockWebView)
        //ASSERT
        XCTAssertTrue(mockWebViewInstrumentation.injectSessionIdCalled, "injectSessionId should have been called on the mock module")
    }

    class MockWebViewInstrumentation: WebViewInstrumentationModule {
        var injectSessionIdCalled = false
        func injectSessionId(into webView: WKWebView) {
            injectSessionIdCalled = true
        }
    }
}
