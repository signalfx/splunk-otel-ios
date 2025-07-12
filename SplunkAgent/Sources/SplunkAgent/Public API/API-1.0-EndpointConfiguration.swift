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

/// A configuration that defines the endpoints for sending telemetry data.
///
/// You can configure endpoints in two ways:
/// 1. By providing a `realm` to send data to the Splunk RUM cloud.
/// 2. By providing custom URLs for a self-hosted or third-party collector.
public struct EndpointConfiguration: Codable, Equatable {

    // MARK: - Public

    /// The Splunk RUM realm to which instrumentation is sent.
    public let realm: String?

    /// The RUM access token for authenticating requests.
    public let rumAccessToken: String?

    /// The endpoint URL for sending traces.
    public let traceEndpoint: URL?

    /// The optional endpoint URL for sending session replay data.
    public let sessionReplayEndpoint: URL?


    // MARK: - Initialization

    /// Initializes the endpoint configuration with a Splunk RUM realm and access token.
    ///
    /// This is the recommended approach for sending data to the Splunk RUM cloud.
    ///
    /// - Parameter realm: The Splunk RUM realm (e.g., "us0").
    /// - Parameter rumAccessToken: The RUM access token for authenticating requests.
    ///
    /// ### Example ###
    /// ```
    /// let config = EndpointConfiguration(
    ///     realm: "us0",
    ///     rumAccessToken: "YOUR_RUM_ACCESS_TOKEN"
    /// )
    /// ```
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

    /// Initializes the endpoint configuration with custom endpoint URLs.
    ///
    /// Use this initializer if you are hosting your own OTel collector or using a different backend.
    ///
    /// - Parameter trace: The URL for sending traces.
    /// - Parameter sessionReplay: The optional URL for sending session replay data. This is required if session replay is enabled.
    ///
    /// ### Example ###
    /// ```
    /// if let traceURL = URL(string: "https://my-collector.com/v1/traces") {
    ///     let config = EndpointConfiguration(trace: traceURL)
    /// }
    /// ```
    public init(trace: URL, sessionReplay: URL? = nil) {
        traceEndpoint = trace
        sessionReplayEndpoint = sessionReplay

        realm = nil
        rumAccessToken = nil
    }


    // MARK: - Private methods

    // Constructs the full URL for a given Splunk RUM realm and path.
    private static func realmUrl(for realm: String, path: String) -> URL? {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "rum-ingest.\(realm).signalfx.com"
        urlComponents.path = path

        return urlComponents.url
    }
}


extension EndpointConfiguration: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return """
        Realm: \(realm ?? "nil"), \
        RUM access token: \(rumAccessToken ?? "nil"), \
        Trace endpoint: \(traceEndpoint?.absoluteString ?? "nil"), \
        Session replay endpoint: \(sessionReplayEndpoint?.absoluteString ?? "nil")
        """
    }

    public var debugDescription: String {
        return description
    }
}


extension EndpointConfiguration {

    // MARK: - Authentication

    /// Authenticates an endpoint URL by appending an authentication token to its query string.
    ///
    /// - Parameter url: The URL to authenticate.
    /// - Parameter authToken: The authentication token to append.
    /// - Returns: The authenticated URL, or `nil` if the URL could not be constructed.
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

    /// Validates the endpoint configuration.
    ///
    /// - Throws: `AgentConfigurationError` if the configuration is invalid.
    func validate() throws {

        // Validate rum access token if supplied
        if realm != nil,  rumAccessToken?.isEmpty ?? true {
            throw AgentConfigurationError.invalidRumAccessToken(supplied: rumAccessToken)
        }

        // Validate trace endpoint
        if traceEndpoint == nil {
            throw AgentConfigurationError.invalidEndpoint(supplied: self)
        }

        // Validate session replay endpoint
        if
            realm != nil, rumAccessToken != nil,
            sessionReplayEndpoint == nil {

            throw AgentConfigurationError.invalidEndpoint(supplied: self)
        }
    }
}