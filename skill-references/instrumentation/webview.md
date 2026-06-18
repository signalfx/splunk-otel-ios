# WebView

## Load when

Load for `WKWebView`, Browser RUM session correlation, WebView migration, or
WebView troubleshooting.

## Do not load when

Do not load for apps with no WebView usage.

## Source files to verify

- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/WebView-Instrumentation.md`
- `SplunkAgent/Sources/SplunkAgent/Public API/Modules/WebViewInstrumentation/`
- `SplunkWebView/`
- `SplunkAgent/Sources/SplunkAgentObjC/Modules/WebViewInstrumentation/`
- Host App `WKWebView` creation and navigation policy

## Required output additions

- WebViews found and ownership/trust evidence.
- Browser RUM precondition.
- Bridge approval state.
- Call-before-load and `userContentController` caveats.

## Approval gate

Do not bridge a `WKWebView` unless the user approves and evidence shows the app
controls the loaded pages and they are instrumented with Splunk Browser RUM.

Warn that the native session identifier becomes available to loaded JavaScript.
Call bridge setup before loading web content. Avoid replacing
`WKUserContentController` after integration.

For third-party or arbitrary web content, recommend not bridging unless the user
provides a clear trust model.

