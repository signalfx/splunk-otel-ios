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

/// Endpoint configuration builds OTel collector urls.
///
/// URLs can be defined either by providing the `realm`, which sends all instrumentation to the Splunk RUM collector to a specified realm;
/// or by providing a custom `traces` and optionally a custom `session replay` url.
public struct EndpointConfiguration: Codable, Equatable {

    // MARK: - Public

    /// Defines a Splunk RUM realm to which all instrumentation will be sent to.
    public let realm: String?

    /// A RUM access token, authenticates requests to the RUM instrumentation collector.
    public let rumAccessToken: String?

    /// Defines a custom trace endpoint to which all traces will be sent to.
    public let traceEndpoint: URL?

    /// Defines an optional custom session replay endpoint to which all session replay data will be sent to.
    public let sessionReplayEndpoint: URL?


    // MARK: - Initialization

    /// Initialize the endpoint configuration with the Splunk RUM realm and RUM access token.
    ///
    /// - Parameters:
    ///   - realm: A Splunk RUM realm to which all instrumentation will be sent to.
    ///   - rumAccessToken: A required RUM access token to authenticate requests with the RUM instrumentation collector.
    public init(realm: String, rumAccessToken: String) {
        self.realm = realm
        self.rumAccessToken = rumAccessToken

        let traceUrl = Self.realmUrl(for: realm, path: "/v1/rumotlp")
        let sessionReplayUrl = Self.realmUrl(for: realm, path: "/v1/rumreplay")

        // Authenticate trace url
        if let traceUrl {
            traceEndpoint = Self.authenticate(url: traceUrl, with: rumAccessToken)
        } else {
            traceEndpoint = nil
        }

        // Authenticate session replay url
        if let sessionReplayUrl {
            sessionReplayEndpoint = Self.authenticate(url: sessionReplayUrl, with: rumAccessToken)
        } else {
            sessionReplayEndpoint = nil
        }
    }

    /// Initialize the endpoint configuration with a custom trace url and an optional session replay url.
    ///
    /// - Parameters:
    ///   - trace: A trace URL to which all traces wil be sent to.
    ///   - sessionReplay: An optional session replay url, to which session replay data will be sent to. Required if session replay functionality is enabled.
    public init(trace: URL, sessionReplay: URL? = nil) {
        traceEndpoint = trace
        sessionReplayEndpoint = sessionReplay

        realm = nil
        rumAccessToken = nil
    }


    // MARK: - Private methods

    private static func realmUrl(for realm: String, path: String) -> URL? {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "rum-ingest.\(realm).signalfx.com"
        urlComponents.path = path

        return urlComponents.url
    }
}


extension EndpointConfiguration: CustomStringConvertible, CustomDebugStringConvertible {

    /// A human-readable string representation of the `EndpointConfiguration` instance.
    public var description: String {
        """
        Realm: \(realm ?? "nil"), \
        RUM access token: \(rumAccessToken ?? "nil"), \
        Trace endpoint: \(traceEndpoint?.absoluteString ?? "nil"), \
        Session replay endpoint: \(sessionReplayEndpoint?.absoluteString ?? "nil")
        """
    }

    /// A string representation of the `EndpointConfiguration` instance intended for diagnostic output, identical to `description`.
    public var debugDescription: String {
        description
    }
}


extension EndpointConfiguration {

    // MARK: - Authentication

    /// Authenticates an endpoint URL by appending the auth token to the URL's query.
    ///
    /// - Returns: Authenticated url, or `nil` if building the url fails.
    private static func authenticate(url: URL, with authToken: String) -> URL? {

        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        urlComponents.queryItems = [URLQueryItem(name: "auth", value: authToken)]

        guard urlComponents.queryItems?.count ?? 0 > 0 else {
            return nil
        }

        guard let authenticatedUrl = urlComponents.url else {
            return nil
        }

        return authenticatedUrl
    }
}


extension EndpointConfiguration {

    // MARK: - Validation

    /// Validate endpoint configuration.
    ///
    /// - Throws: `AgentConfigurationError` if provided configuration is invalid.
    func validate() throws {

        // Validate rum access token if supplied
        if realm != nil, rumAccessToken?.isEmpty ?? true {
            throw AgentConfigurationError.invalidRumAccessToken(supplied: rumAccessToken)
        }

        // Validate trace endpoint
        if traceEndpoint == nil {
            throw AgentConfigurationError.invalidEndpoint(supplied: self)
        }

        // Validate session replay endpoint
        if realm != nil, rumAccessToken != nil,
            sessionReplayEndpoint == nil
        {

            throw AgentConfigurationError.invalidEndpoint(supplied: self)
        }
    }
}
