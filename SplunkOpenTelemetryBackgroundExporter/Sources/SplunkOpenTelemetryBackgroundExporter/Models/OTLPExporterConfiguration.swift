//
/*
Copyright 2025 Splunk Inc.

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

// MARK: - OTLPExporterConfiguration

/// Configuration for OTLP exporters.
///
/// This struct replaces the dependency on `OtlpConfiguration` from the
/// `OpenTelemetryProtocolExporterCommon` package.
public struct OTLPExporterConfiguration {

    // MARK: - Static Constants

    /// Default timeout interval for OTLP export requests (10 seconds).
    public static let defaultTimeoutInterval: TimeInterval = 10


    // MARK: - Properties

    /// Timeout for export requests.
    public let timeout: TimeInterval


    // MARK: - Initialization

    /// Creates a new OTLP exporter configuration.
    ///
    /// - Parameter timeout: Timeout for export requests (defaults to 10 seconds).
    public init(timeout: TimeInterval = defaultTimeoutInterval) {
        self.timeout = timeout
    }
}


// MARK: - OTLPHTTPHeaders

/// HTTP header constants and helpers for OTLP exporters.
///
/// This enum provides HTTP header values that were previously from
/// `OpenTelemetryProtocolExporterCommon` package.
public enum OTLPHTTPHeaders {

    // MARK: - Header Keys

    /// The User-Agent HTTP header key.
    public static let userAgentKey = "User-Agent"


    // MARK: - Header Values

    /// The User-Agent header value for OTLP requests.
    public static var userAgent: String {
        let osName: String
        #if os(iOS)
            osName = "iOS"
        #elseif os(tvOS)
            osName = "tvOS"
        #elseif os(visionOS)
            osName = "visionOS"
        #elseif os(macOS)
            osName = "macOS"
        #else
            osName = "unknown"
        #endif

        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return "OTel-OTLP-Exporter-Swift/\(OTLPVersion.version) (\(osName); \(osVersion))"
    }
}


// MARK: - OTLPEnvVarHeaders

/// Environment variable header extraction for OTLP exporters.
///
/// This enum provides functionality to extract OTLP headers from environment
/// variables, replacing the dependency on `EnvVarHeaders` from the
/// `OpenTelemetryProtocolExporterCommon` package.
public enum OTLPEnvVarHeaders {

    // MARK: - Environment Variable Keys

    /// Environment variable key for OTLP headers.
    private static let otlpHeadersEnvVar = "OTEL_EXPORTER_OTLP_HEADERS"

    /// Environment variable key for OTLP trace headers.
    private static let otlpTracesHeadersEnvVar = "OTEL_EXPORTER_OTLP_TRACES_HEADERS"

    /// Environment variable key for OTLP logs headers.
    private static let otlpLogsHeadersEnvVar = "OTEL_EXPORTER_OTLP_LOGS_HEADERS"

    /// Environment variable key for OTLP metrics headers.
    private static let otlpMetricsHeadersEnvVar = "OTEL_EXPORTER_OTLP_METRICS_HEADERS"


    // MARK: - Public Properties

    /// Headers parsed from OTLP environment variables.
    ///
    /// Parses headers from `OTEL_EXPORTER_OTLP_HEADERS` environment variable.
    /// Format: "key1=value1,key2=value2"
    public static var attributes: [(String, String)]? {
        parseHeaders(from: otlpHeadersEnvVar)
    }


    // MARK: - Private Methods

    /// Parses headers from an environment variable.
    ///
    /// - Parameter envVar: The environment variable name.
    /// - Returns: An array of key-value tuples, or nil if not set.
    private static func parseHeaders(from envVar: String) -> [(String, String)]? {
        guard let value = ProcessInfo.processInfo.environment[envVar] else {
            return nil
        }

        var headers: [(String, String)] = []

        // Split by comma and parse key=value pairs
        let pairs = value.components(separatedBy: ",")
        for pair in pairs {
            let keyValue = pair.components(separatedBy: "=")
            if keyValue.count == 2 {
                let key = keyValue[0].trimmingCharacters(in: .whitespaces)
                let val = keyValue[1].trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    headers.append((key, val))
                }
            }
        }

        return headers.isEmpty ? nil : headers
    }
}
