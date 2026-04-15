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

    /// HTTP request header names to capture as span attributes.
    ///
    /// When set, matching headers from outgoing requests are added to the HTTP span
    /// as `http.request.header.<lowercased-name>`. Header matching is case-insensitive.
    /// Default is `nil` (no request headers captured).
    public var capturedRequestHeaders: [String]?

    /// HTTP response header names to capture as span attributes.
    ///
    /// When set, matching headers from incoming responses are added to the HTTP span
    /// as `http.response.header.<lowercased-name>`. Header matching is case-insensitive.
    /// Default is `nil` (no response headers captured).
    ///
    /// Note: Multi-value headers are comma-joined. Avoid capturing headers whose
    /// values may contain commas (e.g., `Set-Cookie`) as they cannot be reliably
    /// parsed back.
    public var capturedResponseHeaders: [String]?

    /// Indicates whether W3C trace context headers should be injected into outgoing HTTP requests.
    ///
    /// When enabled (default), the `traceparent` and `tracestate` headers are automatically
    /// added to outgoing requests to enable distributed trace correlation with backend services.
    ///
    /// Default value is `true`.
    public var injectTraceHeaders: Bool = true

    // MARK: init()

    /// Initializes new module configuration.
    ///
    /// - Parameters:
    ///   - isEnabled: A `Boolean` value sets whether the module is enabled.
    ///   - ignoreURLs: If present, the module will not report on these URLs.
    ///   - injectTraceHeaders: If `true` (default), W3C trace context headers are injected into requests.
    ///   - capturedRequestHeaders: HTTP request header names to capture as span attributes.
    ///   - capturedResponseHeaders: HTTP response header names to capture as span attributes.
    public init(
        isEnabled: Bool = true,
        ignoreURLs: IgnoreURLs? = nil,
        injectTraceHeaders: Bool = true,
        capturedRequestHeaders: [String]? = nil,
        capturedResponseHeaders: [String]? = nil
    ) {
        self.isEnabled = isEnabled
        self.ignoreURLs = ignoreURLs
        self.injectTraceHeaders = injectTraceHeaders
        self.capturedRequestHeaders = capturedRequestHeaders
        self.capturedResponseHeaders = capturedResponseHeaders
    }
}
