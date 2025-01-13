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


import Foundation
import MRUMSharedProtocols
import MRUMLogger
import OpenTelemetryApi
import URLSessionInstrumentation
import OpenTelemetrySdk
import ResourceExtension
import SignPostIntegration

public class NetworkInstrumentation {
    
    // MARK: - Private
    
    private let internalLogger = InternalLogger(configuration: .networkInstrumentation(category: "NetworkInstrumentation"))

    // MARK: - Public

    /// Endpoint of the backend, needs to be excluded from instrumentation
    public var traceEndpointURL: URL?

    /// An instance of the Agent shared state object, which is used to obtain agent's state, e.g. a session id.
    public unowned var sharedState: AgentSharedState?

    public required init() {    // For Module conformance
    }
    
    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any RemoteModuleConfiguration)?) {
 
        // Start up NSURLSession instrumentation
        _ = URLSessionInstrumentation(configuration: URLSessionInstrumentationConfiguration(shouldRecordPayload: shouldRecordPayload, shouldInstrument: shouldInstrument, createdRequest: createdRequest, receivedResponse: receivedResponse, receivedError: receivedError))
    }
    
    // Callback methods to modify URLSession monitoring
    func shouldInstrument(URLRequest: URLRequest) -> Bool {
        // Code here could filter based on URLRequest

        /* Save this until we add the feature into the Agent side API
        guard agentConfiguration?.appDCloudShouldInstrument?(URLRequest) ?? true else {
            return ((agentConfiguration?.appDCloudShouldInstrument!(URLRequest)) != nil)
        }
        */
        let requestEndpoint = URLRequest.description

        if let traceEndpointURL {
            let traceEndpoint = traceEndpointURL.absoluteString
            if requestEndpoint.contains(traceEndpoint) {
                self.internalLogger.log(level: .debug) {
                    "Should Not Instrument Backend URL \(URLRequest.description)"
                }
                return false
            }
        }
        else {
            self.internalLogger.log(level: .debug) {
                "Should Not Instrument, Backend URL not yet configured."
            }
            return false
        }
        // Leave the localhost test in place for the test case where we have two endpoints,
        // both collector and zipkin on local.
        if requestEndpoint.hasPrefix("http://localhost") {
            self.internalLogger.log(level: .debug) {
                "Should Not Instrument Localhost \(URLRequest.description)"
            }
            return false
        }
        else {
            self.internalLogger.log(level: .debug) {
                "Should Instrument \(URLRequest.description)"
            }
            return true
        }
    }

    func shouldRecordPayload(URLSession: URLSession) -> Bool {
        return true
    }

    func createdRequest(URLRequest: URLRequest, Span: Span) -> Void {
        let key = SemanticAttributes.httpRequestContentLength
        let body = URLRequest.httpBody
        let length = body?.count ?? 0
        Span.setAttribute(key: key, value: length)

        if let sharedState {
            let sessionID = sharedState.sessionId
            Span.setAttribute(key: "session.id", value: sessionID)
        }
    }

    func receivedResponse(URLResponse: URLResponse, DataOrFile: DataOrFile?, Span: Span) -> Void {
        let key = SemanticAttributes.httpResponseContentLength
        let response = URLResponse as? HTTPURLResponse
        let length = response?.expectedContentLength ?? 0
        Span.setAttribute(key: key, value: Int(length))

        /* Save this until we add the feature into the Agent side API
        guard ((agentConfiguration?.appDCloudNetworkResponseCallback?(URLResponse)) == nil) else {
            let newUrl = ((agentConfiguration?.appDCloudNetworkResponseCallback!(URLResponse)) != nil)
            key = SemanticAttributes.httpUrl
            Span.setAttribute(key: key, value: newUrl)
            return
        }
        */
    }
    
    func receivedError(Error: Error, DataOrFile: DataOrFile?, HTTPStatus: HTTPStatus, Span: Span) -> Void {
        
        print(Error)
        self.internalLogger.log(level: .error) {
            "Error: \(Error.localizedDescription), Status: \(HTTPStatus)"
        }
    }
}

