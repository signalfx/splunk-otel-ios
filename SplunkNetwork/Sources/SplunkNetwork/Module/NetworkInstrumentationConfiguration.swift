//
/*
Copyright 2026 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import Foundation
import SplunkCommon

/// Network Instrumentation module configuration.
public struct NetworkInstrumentationConfiguration: ModuleConfiguration {

    // MARK: - Public

    /// Indicates whether the Module is enabled.
    ///
    /// Default value is `true`.
    public var isEnabled: Bool = true

    /// Describes URLs to be ignored by the module when reporting on network activity.
    public var ignoreURLs: IgnoreURLs?

    /// Indicates whether W3C trace context headers should be injected into outgoing HTTP requests.
    ///
    /// When enabled (default), the `traceparent` and `tracestate` headers are automatically
    /// added to outgoing requests to enable distributed trace correlation with backend services.
    ///
    /// Default value is `true`.
    public var injectTraceHeaders: Bool = true

    /// Indicates whether network timing breakdown data should be collected.
    ///
    /// When enabled, `URLSessionTaskTransactionMetrics` are captured for each instrumented
    /// HTTP request and emitted as a log record with timing attributes (DNS, connect, TLS,
    /// request, and response phases).
    ///
    /// Requires iOS 15+ at runtime. On earlier versions this setting has no effect.
    ///
    /// Default value is `true`.
    public var collectNetworkTiming: Bool = true

    // MARK: init()

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameters:
    ///   - isEnabled: A `Boolean` value sets whether the module is enabled.
    ///   - ignoreURLs: If present, the module will not report on these URLs.
    ///   - injectTraceHeaders: If `true` (default), W3C trace context headers are injected into requests.
    ///   - collectNetworkTiming: If `true` (default), network timing breakdowns are captured for HTTP requests (iOS 15+ only).
    public init(
        isEnabled: Bool = true,
        ignoreURLs: IgnoreURLs? = nil,
        injectTraceHeaders: Bool = true,
        collectNetworkTiming: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.ignoreURLs = ignoreURLs
        self.injectTraceHeaders = injectTraceHeaders
        self.collectNetworkTiming = collectNetworkTiming
    }
}
