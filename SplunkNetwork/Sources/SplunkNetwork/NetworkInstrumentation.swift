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
import OpenTelemetrySdk
import ResourceExtension
import SignPostIntegration
@_spi(SplunkInternal) import SplunkCommon
import URLSessionInstrumentation

public class NetworkInstrumentation {

    // MARK: - Private

    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "NetworkInstrumentation")

    /// Holds regex patterns from IgnoreURLs API
    private var ignoreURLs = IgnoreURLs()

    private let delegateClassNames = [
        "__NSURLSessionLocal",
        "__NSCFURLSessionConnection",
        "__NSCFURLLocalSessionConnection",
        "__NSCFURLSession",
        "__NSCFURLSessionTask",
        "__NSCFURLSessionDataTask",
        "__NSCFURLSessionDownloadTask",
        "__NSCFURLSessionUploadTask",
        "NSURLSessionDefault"
    ]

    // MARK: - Public

    /// Endpoints excluded from network instrumentation.
    public var excludedEndpoints: [URL]?

    /// An instance of the Agent shared state object, which is used to obtain agent's state, e.g. a session id.
    public unowned var sharedState: AgentSharedState?

    // For Module conformance
    public required init() {}

    /// Installs the Network Instrumentation module
    /// - Parameters:
    ///   - configuration: Module specific local configuration
    ///   - remoteConfiguration: Module specific remote configuration
    public func install(with configuration: (any ModuleConfiguration)?,
                        remoteConfiguration: (any RemoteModuleConfiguration)?) {

        var delegateClassesToInstrument = nil as [AnyClass]?
        var delegateClasses: [AnyClass] = []
        let config = configuration as? Configuration

        // Start the network instrumentation if it's enabled or if no configuration is provided.
        if config?.isEnabled ?? true {

            if let ignoreURLsParameter = config?.ignoreURLs {
                ignoreURLs = ignoreURLsParameter
            }

            // find concrete delegate classes
            for className in delegateClassNames {
                if let concreteClass = NSClassFromString(className) {
                    delegateClasses.append(concreteClass)
                }
            }
            // empty array defaults to standard exhaustive search
            if !delegateClasses.isEmpty {
                delegateClassesToInstrument = delegateClasses
            } else {
                logger.log(level: .debug) {
                    """
                    Standard Delegate classes not found, using exhaustive delegate class search.
                    This may incur performance overhead during startup.
                    """
                }
            }

            // Start up URLSession instrumentation
            _ = URLSessionInstrumentation(
                configuration: URLSessionInstrumentationConfiguration(
                    shouldRecordPayload: shouldRecordPayload,
                    shouldInstrument: shouldInstrument,
                    createdRequest: createdRequest,
                    receivedResponse: receivedResponse,
                    receivedError: receivedError,
                    delegateClassesToInstrument: delegateClassesToInstrument
                )
            )
        }
    }

    // Callback methods to modify URLSession monitoring
    func shouldInstrument(URLRequest: URLRequest) -> Bool {
        // Code here could filter based on URLRequest

        /* Save this until we add the feature into the Agent side API
         guard agentConfiguration?.appDCloudShouldInstrument?(URLRequest) ?? true else {
         return ((agentConfiguration?.appDCloudShouldInstrument!(URLRequest)) != nil)
         }
         */

        // Filter using ignoreURLs API
        if let urlToTest = URLRequest.url {
            if ignoreURLs.matches(url: urlToTest) {
                logger.log(level: .debug) {
                    "URL excluded via IgnoreURLs API \(URLRequest.description)"
                }
                return false
            }
        }

        let requestEndpoint = URLRequest.description
        if let excludedEndpoints {
            for excludedEndpoint in excludedEndpoints where requestEndpoint.contains(excludedEndpoint.absoluteString) {
                logger.log(level: .debug) {
                    "Should Not Instrument Backend URL \(URLRequest.description)"
                }
                return false
            }
        } else {
            logger.log(level: .debug) {
                "Should Not Instrument, Backend URL not yet configured."
            }
            return false
        }
        // Leave the localhost test in place for the test case where we have two endpoints,
        // both collector and zipkin on local.
        if requestEndpoint.hasPrefix("http://localhost") {
            logger.log(level: .debug) {
                "Should Not Instrument Localhost \(URLRequest.description)"
            }
            return false
        } else {
            logger.log(level: .debug) {
                "Should Instrument \(URLRequest.description)"
            }
            return true
        }
    }

    func shouldRecordPayload(URLSession: URLSession) -> Bool {
        return true
    }

    func createdRequest(URLRequest: URLRequest, span: Span) {
        let body = URLRequest.httpBody
        let length = body?.count ?? 0
        span.clearAndSetAttribute(key: SemanticAttributes.httpRequestBodySize, value: length)
        let method = URLRequest.httpMethod ?? "_OTHER"
        span.clearAndSetAttribute(key: SemanticAttributes.httpRequestMethod, value: method)
        span.clearAndSetAttribute(key: "component", value: "http")

        if let url = URLRequest.url {
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
            } else {
                let defaultPort = url.scheme?.lowercased() == "https" ? 443 : 80
                span.clearAndSetAttribute(key: "network.peer.port", value: defaultPort)
            }

            if let scheme = url.scheme?.lowercased() {
                span.clearAndSetAttribute(key: "network.protocol.name", value: scheme)
            }

            span.clearAndSetAttribute(key: "url.full", value: url.absoluteString)
        }

        if let sharedState {
            let sessionID = sharedState.sessionId
            span.clearAndSetAttribute(key: "session.id", value: sessionID)
        }
    }

    func addLinkToSpan(span: Span, valStr: String) {

        let serverTimingPattern = #"traceparent;desc=['"]00-([0-9a-f]{32})-([0-9a-f]{16})-01['"]"#

        guard let regex = try? NSRegularExpression(pattern: serverTimingPattern) else {
            logger.log(level: .fault) {
                "Regex failed to compile"
            }

            // Intentional hard failure in both Debug and Release builds
            preconditionFailure("""
                                Regex failed to compile. Likely programmer error in
                                edit of serverTimingPattern
                                regex: #\(serverTimingPattern)#
                                """)
        }

        // Match the regex against the input string
        let result = regex.matches(in: valStr, range: NSRange(location: 0, length: valStr.utf16.count))

        // Ensure there's exactly one match and the correct number of capture groups
        guard result.count == 1, result[0].numberOfRanges == 3,
              let traceIdRange = Range(result[0].range(at: 1), in: valStr),
              let spanIdRange = Range(result[0].range(at: 2), in: valStr) else {
            // If the match or capture groups are invalid, log and return early
            // Also, prevent over-long log output
            let truncatedValStr = valStr.count > 255 ? String(valStr.prefix(252)) + "..." : valStr

            logger.log(level: .debug) {
                "Failed to match traceparent string: \(truncatedValStr)"
            }

            return
        }

        let traceId = String(valStr[traceIdRange])
        let spanId = String(valStr[spanIdRange])

        span.clearAndSetAttribute(key: "link.traceId", value: traceId)
        span.clearAndSetAttribute(key: "link.spanId", value: spanId)
    }

    func receivedResponse(URLResponse: URLResponse, dataOrFile: DataOrFile?, span: Span) {
        let response = URLResponse as? HTTPURLResponse
        let length = response?.expectedContentLength ?? 0
        span.clearAndSetAttribute(key: SemanticAttributes.httpResponseBodySize, value: Int(length))
        span.clearAndSetAttribute(key: SemanticAttributes.httpResponseStatusCode, value: Int(response?.statusCode ?? 0))

        // Try to capture IP address from the response/connection
        if let httpResponse = response {
            // Update network.peer.address with actual IP if we can get it
            if let ipAddress = getIPAddressFromResponse(httpResponse) {
                span.clearAndSetAttribute(key: "network.peer.address", value: ipAddress)
            }
        }

        if let httpResponse = response {
            let protocolVersion = determineHTTPProtocolVersion(httpResponse)
            span.clearAndSetAttribute(key: "http.protocol.version", value: protocolVersion)

            for (key, val) in httpResponse.allHeaderFields {
                if let keyStr = key as? String,
                   let valStr = val as? String,
                   keyStr.caseInsensitiveCompare("server-timing") == .orderedSame,
                   valStr.contains("traceparent") {
                    addLinkToSpan(span: span, valStr: valStr)
                }
            }
        }

        // removes obsolete attributes
        removeObsoleteAttributes(from: span)

        /* Save this until we add the feature into the Agent side API
        guard ((agentConfiguration?.appDCloudNetworkResponseCallback?(URLResponse)) == nil) else {
            let newUrl = ((agentConfiguration?.appDCloudNetworkResponseCallback!(URLResponse)) != nil)
            key = SemanticAttributes.httpUrl
            Span.setAttribute(key: key, value: newUrl)
            return
        }
        */
    }

    private func determineHTTPProtocolVersion(_ response: HTTPURLResponse) -> String {
        // Check for HTTP/2 server indicators
        if let serverHeader = response.value(forHTTPHeaderField: "Server") {
            if serverHeader.lowercased().contains("http/2") ||
               serverHeader.lowercased().contains("h2") {
                return "2.0"
            }
        }

        // Check for HTTP/2 specific headers
        if response.value(forHTTPHeaderField: "X-Firefox-Spdy") != nil ||
           response.value(forHTTPHeaderField: "X-Google-Spdy") != nil {
            return "2.0"
        }

        return "1.1"
    }

    private func getIPAddressFromResponse(_ response: HTTPURLResponse) -> String? {
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

    private func isValidIPAddress(_ ipString: String) -> Bool {
        // Check for IPv4
        let ipv4Pattern = #"""
            ^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$
            """#
        if ipString.range(of: ipv4Pattern, options: .regularExpression) != nil {
            return true
        }

        // Check for IPv6
        let ipv6Pattern = #"^(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::1$|^::$"#
        if ipString.range(of: ipv6Pattern, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    // Removes obsolete attributes from the span
    private func removeObsoleteAttributes(from span: Span) {
        // Attributes to be removed
        let attributesToRemove = [
            SemanticAttributes.httpUrl,
            SemanticAttributes.httpTarget,
            SemanticAttributes.netPeerName,
            SemanticAttributes.httpStatusCode,
            SemanticAttributes.httpMethod,
            SemanticAttributes.httpScheme
        ]

        for key in attributesToRemove {
            // Setting the value to nil will remove the key
            span.setAttribute(key: key.rawValue, value: nil)
        }
    }

    func receivedError(error: Error, dataOrFile: DataOrFile?, HTTPStatus: HTTPStatus, span: Span) {
        span.clearAndSetAttribute(key: "error", value: true)
        span.clearAndSetAttribute(key: "error.message", value: error.localizedDescription)
        span.clearAndSetAttribute(key: "error.type", value: String(describing: type(of: error)))
        span.clearAndSetAttribute(key: SemanticAttributes.httpResponseStatusCode, value: HTTPStatus)

        // removes obsolete attributes
        removeObsoleteAttributes(from: span)

        logger.log(level: .error) {
            "Error: \(error.localizedDescription), Status: \(HTTPStatus)"
        }
    }
}
