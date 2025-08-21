# Modules Overview

The Splunk RUM agent is composed of several modules, each responsible for a specific type of instrumentation. Some are enabled by default, while others require manual activation.

## Available Modules

Below is a list of the primary modules. Modules with a public API can be accessed as properties on the ``SplunkRum`` instance you retain after installation.

| Module | Public API Access | Summary |
|---|---|---|
| **App Startup Tracking** | *None (Automatic)* | Measures cold, warm, and hot application start times. <br><doc:App-Startup-Tracking> |
| **Crash Reporting** | *None (Automatic)* | Captures and reports application crashes on the next launch. <br><doc:Crash-Reporting> |
| **Custom Tracking** | ``SplunkRum/customTracking`` | Manually track custom events, errors, and workflows. <br><doc:Custom-Event-and-Workflow-Reporting> |
| **Navigation Tracking** | ``SplunkRum/navigation`` | Tracks screen transitions, either automatically or manually. <br><doc:Navigation-Tracking> |
| **Network Monitoring** | *None (Configuration only)* | Instruments `URLSession` requests and network status changes. <br><doc:Network-Monitoring> |
| **Session Replay** | ``SplunkRum/sessionReplay`` | Provides a visual replay of user sessions. <br><doc:Session-Replay> |
| **Slow & Frozen Frames** | ``SplunkRum/slowFrameDetector`` | Detects and reports UI frames that are slow or frozen. <br><doc:Slow-and-Frozen-Frame-Detection> |
| **UI Interaction Tracking** | *None (Configuration only)* | Automatically captures user taps on UI elements. <br><doc:UI-Interaction-Tracking> |
| **WebView Instrumentation** | ``SplunkRum/webViewNativeBridge`` | Links native RUM sessions with Browser RUM in `WKWebView`. <br><doc:WebView-Instrumentation> |