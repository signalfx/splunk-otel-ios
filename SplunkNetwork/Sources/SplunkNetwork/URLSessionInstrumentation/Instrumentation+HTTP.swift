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

import CiscoLogger
import Foundation
import OpenTelemetryApi
@_spi(SplunkInternal) import SplunkCommon

/// Determines the HTTP protocol version from the response headers.
///
/// - Parameter response: The HTTP URL response to analyze.
/// - Returns: The protocol version string ("2.0" for HTTP/2, "1.1" for HTTP/1.1).
func determineHTTPProtocolVersion(_ response: HTTPURLResponse) -> String {
    // Check for HTTP/2 server indicators
    if let serverHeader = response.value(forHTTPHeaderField: "Server") {
        if serverHeader.lowercased().contains("http/2") || serverHeader.lowercased().contains("h2") {
            return "2.0"
        }
    }

    // Check for HTTP/2 specific headers
    if response.value(forHTTPHeaderField: "X-Firefox-Spdy") != nil || response.value(forHTTPHeaderField: "X-Google-Spdy") != nil {
        return "2.0"
    }
    return "1.1"
}

/// Extracts the IP address from HTTP response headers.
///
/// Checks X-Forwarded-For and X-Real-IP headers for IP address information.
///
/// - Parameter response: The HTTP URL response to analyze.
/// - Returns: The IP address string if found and valid, `nil` otherwise.
func getIPAddressFromResponse(_ response: HTTPURLResponse) -> String? {
    // Some proxies or load balancers add headers with IP information
    if let forwardedFor = response.value(forHTTPHeaderField: "X-Forwarded-For") {
        // X-Forwarded-For can contain multiple IPs, take the first one
        let ips = forwardedFor.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if let firstIP = ips.first, isValidIPAddress(firstIP) {
            return firstIP
        }
    }
    if let realIP = response.value(forHTTPHeaderField: "X-Real-IP") {
        if isValidIPAddress(realIP) {
            return realIP
        }
    }
    return nil
}

/// Adds trace linking information to a span from server-timing headers.
///
/// Parses traceparent information from server-timing headers and adds it as span attributes.
///
/// - Parameters:
///   - span: The span to add linking information to.
///   - valStr: The server-timing header value string.
func addLinkToSpan(span: Span, valStr: String) {

    let serverTimingPattern = #"traceparent;desc=['"]00-([0-9a-f]{32})-([0-9a-f]{16})-01['"]"#
    guard let regex = try? NSRegularExpression(pattern: serverTimingPattern) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Regex failed to compile"
        }

        // Intentional hard failure in both Debug and Release builds
        preconditionFailure(
            """
            Regex failed to compile. Likely programmer error in
            edit of serverTimingPattern
            regex: #\(serverTimingPattern)#
            """
        )
    }

    // Match the regex against the input string
    let result = regex.matches(in: valStr, range: NSRange(location: 0, length: valStr.utf16.count))

    // Ensure there's exactly one match and the correct number of capture groups
    guard result.count == 1, result[0].numberOfRanges == 3,
        let traceIdRange = Range(result[0].range(at: 1), in: valStr),
        let spanIdRange = Range(result[0].range(at: 2), in: valStr)
    else {
        // If the match or capture groups are invalid, log and return early
        // Also, prevent over-long log output
        let truncatedValStr = valStr.count > 255 ? String(valStr.prefix(252)) + "..." : valStr

        NetworkInstrumentationManager.shared.logger.log(level: .debug) {
            "Failed to match traceparent string: \(truncatedValStr)"
        }

        return
    }

    let traceId = String(valStr[traceIdRange])
    let spanId = String(valStr[spanIdRange])

    span.clearAndSetAttribute(key: "link.traceId", value: traceId)
    span.clearAndSetAttribute(key: "link.spanId", value: spanId)
}
