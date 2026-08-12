# WebView

## Approval gate

Do not bridge a `WKWebView` unless the user approves and evidence shows the app
controls the loaded pages and they are instrumented with Splunk Browser RUM.

Warn that the native session identifier becomes available to loaded JavaScript.
Call bridge setup before loading web content. Avoid replacing
`WKUserContentController` after integration.

For third-party or arbitrary web content, recommend not bridging unless the user
provides a clear trust model.

After approval, source-backed Swift API:

```swift
import WebKit

let webView = WKWebView()
agent.webViewNativeBridge.integrateWithBrowserRum(webView)
webView.load(request)
```

Call from the main thread before `load`, `loadHTMLString`, or similar methods.
The bridge registration is intended to be idempotent for a web view, but do not
recreate or replace `webView.configuration.userContentController` afterwards.

ObjC bridge selector is `integrateWithBrowserRumView:` on
`SPLKWebViewInstrumentationModule`.
