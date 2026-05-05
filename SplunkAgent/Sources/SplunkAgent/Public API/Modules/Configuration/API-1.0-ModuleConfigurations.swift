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

/// Navigation module configuration.
public struct NavigationConfiguration: Equatable {

    /// Indicates whether the module is enabled.
    public var isEnabled: Bool

    /// Indicates whether the module should automatically detect navigation in the application.
    public var enableAutomatedTracking: Bool?

    /// Initializes a new configuration.
    public init() {
        isEnabled = true
        enableAutomatedTracking = nil
    }

    /// Initializes a new configuration with preconfigured values.
    ///
    /// - Parameters:
    ///   - isEnabled: Indicates whether the module is enabled.
    ///   - enableAutomatedTracking: Indicates whether the module should automatically detect navigation.
    public init(isEnabled: Bool, enableAutomatedTracking: Bool? = nil) {
        self.isEnabled = isEnabled
        self.enableAutomatedTracking = enableAutomatedTracking
    }
}

/// A collection of regular expressions for URL patterns to ignore.
public class IgnoreURLs: Codable {

    // MARK: - Private

    private var urlPatterns: [NSRegularExpression]


    // MARK: - Initialization

    /// Initializes an empty set of URL patterns.
    public init() {
        urlPatterns = []
    }

    /// Initializes with a set of URL pattern strings.
    ///
    /// - Parameter patterns: Regular expression pattern strings for URLs.
    ///
    /// - Throws: If any pattern is an invalid regular expression.
    public init(patterns: Set<String>) throws {
        urlPatterns = try patterns.map { pattern in
            try NSRegularExpression(pattern: pattern, options: [])
        }
    }

    /// Initializes with an optional regular expression pattern.
    ///
    /// - Parameter pattern: Regular expression for URL pattern matching.
    public init(containing pattern: NSRegularExpression?) {
        if let pattern {
            urlPatterns = [pattern]
        }
        else {
            urlPatterns = []
        }
    }

    /// Initializes from a decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    ///
    /// - Throws: If decoding fails or any pattern is invalid.
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let patterns = try container.decode(Set<String>.self, forKey: .patterns)
        urlPatterns = try patterns.map { pattern in
            try NSRegularExpression(pattern: pattern, options: [])
        }
    }


    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case patterns
    }

    /// Encodes the instance to an encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    ///
    /// - Throws: If encoding fails.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Set(getAllPatterns()), forKey: .patterns)
    }


    // MARK: - Public methods

    /// Clears all URL patterns.
    ///
    /// - Returns: The number of cleared patterns.
    @discardableResult
    public func clearPatterns() -> Int {
        let count = urlPatterns.count
        urlPatterns.removeAll()
        return count
    }

    /// Adds URL pattern strings to the existing set.
    ///
    /// - Parameter patterns: Regular expression pattern strings for URLs to add.
    ///
    /// - Returns: The number of patterns added.
    ///
    /// - Throws: If any new pattern is invalid.
    @discardableResult
    public func addPatterns(_ patterns: Set<String>) throws -> Int {
        let newPatterns = try patterns.map { pattern in
            try NSRegularExpression(pattern: pattern, options: [])
        }

        let existingPatternStrings = Set(urlPatterns.map(\.pattern))
        let uniqueNewPatterns = newPatterns.filter { !existingPatternStrings.contains($0.pattern) }
        urlPatterns.append(contentsOf: uniqueNewPatterns)

        return uniqueNewPatterns.count
    }

    /// Adds a regular expression pattern to the existing set.
    ///
    /// - Parameter pattern: Regular expression pattern to add.
    ///
    /// - Returns: `true` when the pattern was added, or `false` when it already existed.
    @discardableResult
    public func addPattern(_ pattern: NSRegularExpression) -> Bool {
        let existingPatternStrings = Set(urlPatterns.map(\.pattern))

        if !existingPatternStrings.contains(pattern.pattern) {
            urlPatterns.append(pattern)
            return true
        }

        return false
    }

    /// Gets the number of URL patterns.
    public func count() -> Int {
        urlPatterns.count
    }

    /// Gets all URL patterns as strings.
    ///
    /// - Returns: Regular expression pattern strings.
    public func getAllPatterns() -> [String] {
        urlPatterns.map(\.pattern)
    }

    /// Checks if a URL string matches any ignore pattern.
    ///
    /// - Parameter urlString: The URL string to check.
    ///
    /// - Returns: `true` if the URL matches any pattern.
    public func matches(_ urlString: String) -> Bool {
        urlPatterns.contains { regex in
            let range = NSRange(urlString.startIndex..., in: urlString)
            return regex.firstMatch(in: urlString, options: [], range: range) != nil
        }
    }

    /// Checks if a URL matches any ignore pattern.
    ///
    /// - Parameter url: The URL to check.
    ///
    /// - Returns: `true` if the URL matches any pattern.
    public func matches(url: URL) -> Bool {
        matches(url.absoluteString)
    }
}

/// Network instrumentation module configuration.
public struct NetworkInstrumentationConfiguration {

    /// Indicates whether the module is enabled.
    public var isEnabled: Bool

    /// Describes URLs to be ignored by the module when reporting network activity.
    public var ignoreURLs: IgnoreURLs?

    /// Indicates whether W3C trace context headers should be injected into outgoing HTTP requests.
    public var injectTraceHeaders: Bool

    /// HTTP request header names to capture as span attributes.
    public var capturedRequestHeaders: [String]?

    /// HTTP response header names to capture as span attributes.
    public var capturedResponseHeaders: [String]?

    /// Initializes a new configuration.
    ///
    /// - Parameters:
    ///   - isEnabled: Indicates whether the module is enabled.
    ///   - ignoreURLs: URLs that should not be reported by the module.
    ///   - injectTraceHeaders: Indicates whether W3C trace context headers should be injected.
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

/// Network monitor module configuration.
public struct NetworkMonitorConfiguration: Equatable {

    /// Indicates whether the module is enabled.
    public var isEnabled: Bool

    /// Initializes a new configuration.
    ///
    /// - Parameter isEnabled: Indicates whether the module is enabled.
    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
}

/// Slow frame detector module configuration.
public struct SlowFrameDetectorConfiguration: Equatable {

    /// Indicates whether the module is enabled.
    public var isEnabled: Bool

    /// Initializes a new configuration.
    ///
    /// - Parameter isEnabled: Indicates whether the module is enabled.
    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
}

/// Crash reports module configuration.
public struct CrashReportsConfiguration: Equatable {

    /// Indicates whether the module is enabled.
    public var isEnabled: Bool

    /// Initializes a new configuration.
    ///
    /// - Parameter isEnabled: Indicates whether the module is enabled.
    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
}

/// Session Replay module configuration.
public struct SessionReplayConfiguration: Equatable {

    /// Enables or disables Session Replay.
    public var enabled: Bool

    /// Optional local sampling of session replay recording.
    public var samplingRate: Double?

    /// Creates a new Session Replay configuration.
    ///
    /// - Parameters:
    ///   - enabled: Indicates whether Session Replay is enabled.
    ///   - samplingRate: Optional probability in the `<0, 1>` range for recording the current launch.
    public init(enabled: Bool = true, samplingRate: Double? = nil) {
        self.enabled = enabled
        self.samplingRate = samplingRate
    }
}

/// Interactions module configuration.
public struct InteractionsConfiguration: Equatable {

    /// Indicates whether the module is enabled.
    public var isEnabled: Bool

    /// Initializes a new configuration.
    ///
    /// - Parameter isEnabled: Indicates whether the module is enabled.
    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
}

/// WebView instrumentation module configuration.
public struct WebViewInstrumentationConfiguration: Equatable {

    /// Initializes a new configuration.
    public init() {}
}

/// App Start module configuration.
public struct AppStartConfiguration: Equatable {

    /// Initializes a new configuration.
    public init() {}
}

/// App State module configuration.
public struct AppStateConfiguration: Equatable {

    /// Initializes a new configuration.
    public init() {}
}

/// Custom tracking module configuration.
public struct CustomTrackingConfiguration: Equatable {

    /// Initializes a new configuration.
    public init() {}
}
