import WebKit
internal import SplunkWebViewProxy

public class WebViewToNativeBridge {

    // Using the protocol here
    private let module: WebViewInstrumentationModule

    init(module: WebViewInstrumentationModule) {
        self.module = module
    }

    public func integrateWithBrowserRum(_ view: WKWebView) {
        module.injectSessionId(into: view)
    }
}

extension SplunkRum {
    public static let webView = WebViewToNativeBridge(module: WebViewInstrumentationProxy.instance)
}

