# WebView Instrumentation

This module provides a bridge to link native RUM sessions with Browser RUM sessions in `WKWebView`s.

> ``SplunkRum/webViewNativeBridge``

| | |
|---|---|
| **Module** | `SplunkWebView` |
| **Enabled by Default?** | Yes |
| **Public API?** | Yes |

## Overview

If you use Splunk Browser RUM in your web content, this module allows you to correlate the native session with the browser session, providing a complete end-to-end view of the user's journey.

## Usage

For each `WKWebView` that needs to be instrumented, call the integration method.

```swift
import WebKit

let webView = WKWebView()
// ... configure webView ...
SplunkRum.shared.webViewNativeBridge.integrateWithBrowserRum(webView)
webView.loadHTMLString(contentIncludingEmbeddedBRUMLibrary, baseURL: nil)
```

This injects a JavaScript object (window.SplunkRumNative) that the Browser RUM agent can use to retrieve the native session ID. For best results, it is recommended you load the web content that includes the Browser RUM library only after making the `integrateWithBrowserRum()` call.


