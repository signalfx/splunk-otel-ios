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

/// Starts an HTTP span for a URL request.
///
/// - Parameter request: The URL request to create a span for.
/// - Returns: The created span, or `nil` if the request should not be instrumented.
func startHttpSpan(request: URLRequest?) -> Span? {
    guard let request, let url = request.url else {
        return nil
    }

    if !(url.scheme?.lowercased().starts(with: "http") ?? false) {
        return nil
    }
    let method = request.httpMethod ?? "_OTHER"
    let body = request.httpBody
    let length = body?.count ?? 0
    let excludedEndpoints = getNetworkModule()?.excludedEndpoints
    guard let excludedEndpoints else {
        logger.log(level: .debug) {
            "Should Not Instrument, Backend URL not yet configured."
        }
        return nil
    }

    if shouldExcludeURL(url, excludedEndpoints: excludedEndpoints) {
        logger.log(level: .debug) {
            "Should Not Instrument Backend URL \(url.absoluteString)"
        }
        return nil
    }

    // Filter using ignoreURLs API
    if let ignoreURLs = getNetworkModule()?.getIgnoreURLs() {
        if ignoreURLs.matches(url: url) {
            logger.log(level: .debug) {
                "URL excluded via IgnoreURLs API \(url.absoluteString)"
            }
            return nil
        }
    }

    let tracer = OpenTelemetry.instance
        .tracerProvider
        .get(
            instrumentationName: "NetworkInstrumentation",
            instrumentationVersion: getNetworkModule()?.sharedState?.agentVersion
        )

    let span = tracer.spanBuilder(spanName: "HTTP " + method)
        .setStartTime(time: Date())
        .startSpan()

    addDataToSpan(url: url, method: method, length: length, span: span)

    return span
}

/// Ends an HTTP span for a completed URL session task.
///
/// - Parameters:
///   - span: The span to end.
///   - task: The completed URL session task.
func endHttpSpan(span: Span, task: URLSessionTask) {
    let hr: HTTPURLResponse? = task.response as? HTTPURLResponse
    if let hr {
        span.clearAndSetAttribute(key: SemanticAttributes.httpResponseStatusCode, value: hr.statusCode)
        for (key, val) in hr.allHeaderFields {
            if let keyStr = key as? String,
                let valStr = val as? String,
                keyStr.caseInsensitiveCompare("server-timing") == .orderedSame,
                valStr.contains("traceparent")
            {
                addLinkToSpan(span: span, valStr: valStr)
            }
        }

        let length = hr.expectedContentLength
        span.clearAndSetAttribute(key: SemanticAttributes.httpResponseBodySize, value: Int(length))

        // Try to capture IP address from the response/connection
        // Update network.peer.address with actual IP if we can get it
        if let ipAddress = getIPAddressFromResponse(hr) {
            span.clearAndSetAttribute(key: "network.peer.address", value: ipAddress)
        }

        let protocolVersion = determineHTTPProtocolVersion(hr)
        span.clearAndSetAttribute(key: "http.protocol.version", value: protocolVersion)
    }

    if let error = task.error {
        span.clearAndSetAttribute(key: "error", value: true)
        span.clearAndSetAttribute(key: "error.message", value: error.localizedDescription)
        span.clearAndSetAttribute(key: "error.type", value: String(describing: type(of: error)))

        logger.log(level: .error) {
            "Error: \(error.localizedDescription)"
        }
    }

    if task.countOfBytesSent != 0 {
        span.clearAndSetAttribute(key: SemanticAttributes.httpRequestContentLength, value: Int(task.countOfBytesSent))
    }
    span.end()
}

/// Adds HTTP request data as attributes to a span.
///
/// - Parameters:
///   - url: The request URL.
///   - method: The HTTP method.
///   - length: The request body length.
///   - span: The span to add attributes to.
func addDataToSpan(url: URL, method: String, length: Int, span: Span) {
    span.clearAndSetAttribute(key: SemanticAttributes.httpRequestBodySize, value: length)
    span.clearAndSetAttribute(key: SemanticAttributes.httpRequestMethod, value: method)
    span.clearAndSetAttribute(key: "component", value: "http")

    span.clearAndSetAttribute(key: SemanticAttributes.urlPath, value: url.path)
    span.clearAndSetAttribute(key: SemanticAttributes.urlQuery, value: url.query ?? "")
    if let scheme = url.scheme {
        span.clearAndSetAttribute(key: SemanticAttributes.urlScheme, value: scheme)
    }

    if let host = url.host {
        span.clearAndSetAttribute(key: "server.address", value: host)
        // Preload with host in case IP cannot be determined
        span.clearAndSetAttribute(key: "network.peer.address", value: host)
    }

    if let port = url.port {
        span.clearAndSetAttribute(key: "network.peer.port", value: port)
    }
    else {
        let defaultPort = url.scheme?.lowercased() == "https" ? 443 : 80
        span.clearAndSetAttribute(key: "network.peer.port", value: defaultPort)
    }

    if let scheme = url.scheme?.lowercased() {
        span.clearAndSetAttribute(key: "network.protocol.name", value: scheme)
    }

    span.clearAndSetAttribute(key: "url.full", value: url.absoluteString)

    if let sharedState = getNetworkModule()?.sharedState {
        let sessionID: String = sharedState.sessionId
        span.clearAndSetAttribute(key: "session.id", value: sessionID)
    }
}
