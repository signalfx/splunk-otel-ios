import WebKit
import SplunkWebView

public protocol WebViewInstrumentationModule {
    func injectSessionId(into webView: WKWebView)
}

public final class WebViewInstrumentationProxy: WebViewInstrumentationModule {
    public static let instance = WebViewInstrumentationProxy()

    private let module: WebViewInstrumentation = WebViewInstrumentation.instance

    private init() {}

    public func injectSessionId(into webView: WKWebView) {
        module.injectSessionId(into: webView)
    }
}
