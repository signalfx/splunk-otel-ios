# ``SplunkAgent/SplunkRum``

## Overview

The `SplunkRum` class is the primary entry point for configuring and interacting with the Splunk RUM agent for iOS. It provides access to various monitoring modules and allows for custom instrumentation. This class conforms to `Combine.ObservableObject` to make its published properties available for Combine and SwiftUI.

## Topics

### Initializing the Agent

- ``install(with:moduleConfigurations:)``
  A static method to initialize the Splunk RUM agent with a given configuration.

### Core Agent Components

- ``session``
  An object that manages the associated ``SplunkAgent/Session`` for the current user.
- ``user``
  An object that holds the current ``SplunkAgent/User`` and its tracking preferences.
- ``state``
  An object that reflects the current state and settings used for recording (a ``SplunkAgent/RuntimeState`` instance).
- ``globalAttributes``
  An object that contains global attributes (a `MutableAttributes` instance) added to all collected signals.

### Monitoring Modules

- ``sessionReplay``
  Access to the Session Replay module for visual replay of user sessions.
- ``customTracking``
  Access to the Custom Tracking module for manually tracking custom events and workflows.
- ``navigation``
  Access to the Navigation module for tracking screen transitions.
- ``slowFrameDetector``
  Access to the Slow Frame Detector module for reporting slow or frozen UI frames.
- ``webViewNativeBridge``
  Access to the WebView Instrumentation module for linking native RUM sessions with Browser RUM sessions in WebViews.
- ``interactions``
  Access to the Interactions module for capturing user taps on UI elements.

### OpenTelemetry Integration

- ``openTelemetry``
  The underlying OpenTelemetry instance used by the agent for telemetry collection.

### Agent Version

- ``version``
  The current version string of the Splunk RUM agent.

### Deprecated APIs

These APIs are deprecated and will be removed in a future version. Please migrate to the new APIs as indicated.

- ``getSessionId()``
  Use ``session``.`state`.`id` instead.
- ``isInitialized()``
  Use ``state``.`status` instead.
- ``setGlobalAttributes(_:)``
  Use ``globalAttributes`` to modify attributes directly.
- ``removeGlobalAttribute(_:)``
  Use ``globalAttributes`` to modify attributes directly.
- ``debugLog(_:)``
  This method will be removed.
- ``reportError(string:)``
  Use ``customTracking/trackError(_:)`` instead.
- ``reportError(error:)``
  Use ``customTracking/trackError(_:)`` instead.
- ``reportError(exception:)``
  Use ``customTracking/trackException(_:)`` instead.
- ``reportEvent(name:attributes:)``
  Use ``customTracking/trackCustomEvent(_:_:)`` instead.
- ``setScreenName(_:)``
  Use ``navigation/track(screen:)`` instead.
- ``addScreenNameChangeCallback(_:)``
  This method will be removed.
- ``integrateWithBrowserRum(_:)``
  Use ``webViewNativeBridge/integrateWithBrowserRum(_:)`` instead.

