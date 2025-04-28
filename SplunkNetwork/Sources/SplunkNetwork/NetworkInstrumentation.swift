//
/*
Copyright 2024 Splunk Inc.

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

internal import CiscoLogger
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import ResourceExtension
import SignPostIntegration
import SplunkCommon
import URLSessionInstrumentation

public class NetworkInstrumentation {

    // MARK: - Private

    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "NetworkInstrumentation")

    /// Holds regex patterns from IgnoreURLs API
    private let ignoreURLs = IgnoreURLs()

    private let delegateClassNames = [
        "__NSURLSessionLocal",
        "__NSCFURLSessionConnection",
        "__NSCFRULLocalSessionConnection",
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

    public required init() {    // For Module conformance
    }

    public func install(with configuration: (any ModuleConfiguration)?,
                        remoteConfiguration: (any RemoteModuleConfiguration)?) {

        var delegateClassesToInstrument = nil as [AnyClass]?
        var delegateClasses: [AnyClass] = []

        // find concrete delegate classes
        for className in delegateClassNames {
            if let concreteClass = NSClassFromString(className) {
                delegateClasses.append(concreteClass)
            }
        }
        // empty array defaults to standard exhaustive search
        if !delegateClasses.isEmpty {
            delegateClassesToInstrument = delegateClasses
        }

        // Start up URLSession instrumentation
        _ = URLSessionInstrumentation(configuration: URLSessionInstrumentationConfiguration(
            shouldRecordPayload: shouldRecordPayload,
            shouldInstrument: shouldInstrument,
            createdRequest: createdRequest,
            receivedResponse: receivedResponse,
            receivedError: receivedError,
            delegateClassesToInstrument: delegateClassesToInstrument))
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
                self.logger.log(level: .debug) {
                    "URL excluded via IgnoreURLs API \(URLRequest.description)"
                }
                return false
            }
        }

        let requestEndpoint = URLRequest.description
        if let excludedEndpoints {
            for excludedEndpoint in excludedEndpoints where requestEndpoint.contains(excludedEndpoint.absoluteString) {
                self.logger.log(level: .debug) {
                    "Should Not Instrument Backend URL \(URLRequest.description)"
                }
                return false
            }
        } else {
            self.logger.log(level: .debug) {
                "Should Not Instrument, Backend URL not yet configured."
            }
            return false
        }
        // Leave the localhost test in place for the test case where we have two endpoints,
        // both collector and zipkin on local.
        if requestEndpoint.hasPrefix("http://localhost") {
            self.logger.log(level: .debug) {
                "Should Not Instrument Localhost \(URLRequest.description)"
            }
            return false
        } else {
            self.logger.log(level: .debug) {
                "Should Instrument \(URLRequest.description)"
            }
            return true
        }
    }

    func shouldRecordPayload(URLSession: URLSession) -> Bool {
        return true
    }

    func createdRequest(URLRequest: URLRequest, span: Span) {
        let key = SemanticAttributes.httpRequestContentLength
        let body = URLRequest.httpBody
        let length = body?.count ?? 0
        span.setAttribute(key: key, value: length)

        if let sharedState {
            let sessionID = sharedState.sessionId
            span.setAttribute(key: "session.id", value: sessionID)
        }
    }

    let serverTimingPattern = #"traceparent;desc=['\"]00-([0-9a-f]{32})-([0-9a-f]{16})-01['\"]"#

    func addLinkToSpan(span: Span, valStr: String) {
        let regex = try! NSRegularExpression(pattern: serverTimingPattern)
        let result = regex.matches(in: valStr, range: NSRange(location: 0, length: valStr.utf16.count))
        // per standard regex logic, number of matched segments is 3 (whole match plus two () captures)
        if result.count != 1 || result[0].numberOfRanges != 3 {
            return
        }
        let traceId = String(valStr[Range(result[0].range(at: 1), in: valStr)!])
        let spanId = String(valStr[Range(result[0].range(at: 2), in: valStr)!])
        span.setAttribute(key: "link.traceId", value: traceId)
        span.setAttribute(key: "link.spanId", value: spanId)
    }

    func receivedResponse(URLResponse: URLResponse, dataOrFile: DataOrFile?, span: Span) {
        let key = SemanticAttributes.httpResponseContentLength
        let response = URLResponse as? HTTPURLResponse
        let length = response?.expectedContentLength ?? 0
        span.setAttribute(key: key, value: Int(length))

        if response != nil {
            for (key, val) in response!.allHeaderFields {
                if let keyStr = key as? String,
                   let valStr = val as? String,
                   keyStr.caseInsensitiveCompare("server-timing") == .orderedSame,
                   valStr.contains("traceparent") {
                    addLinkToSpan(span: span, valStr: valStr)
                }
            }
        }

        /* Save this until we add the feature into the Agent side API
        guard ((agentConfiguration?.appDCloudNetworkResponseCallback?(URLResponse)) == nil) else {
            let newUrl = ((agentConfiguration?.appDCloudNetworkResponseCallback!(URLResponse)) != nil)
            key = SemanticAttributes.httpUrl
            Span.setAttribute(key: key, value: newUrl)
            return
        }
        */
    }

    func receivedError(error: Error, dataOrFile: DataOrFile?, HTTPStatus: HTTPStatus, span: Span) {
        self.logger.log(level: .error) {
            "Error: \(error.localizedDescription), Status: \(HTTPStatus)"
        }
    }
}
