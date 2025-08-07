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
import SplunkAgent

/// Endpoint configuration builds OTel collector urls.
///
/// URLs can be defined either by providing the `realm`, which sends all instrumentation to the Splunk RUM collector to a specified realm;
/// or by providing a custom `traces` and optionally a custom `session replay` url.
@objc(SPLKEndpointConfiguration)
public final class EndpointConfigurationObjC: NSObject {

    // MARK: - Private

    let configuration: EndpointConfiguration


    // MARK: - Public API

    /// Defines a Splunk RUM realm to which all instrumentation will be sent to.
    @objc
    public var realm: String? {
        configuration.realm
    }

    /// A RUM access token, authenticates requests to the RUM instrumentation collector.
    @objc
    public var rumAccessToken: String? {
        configuration.rumAccessToken
    }

    /// Defines a custom trace endpoint to which all traces will be sent to.
    @objc
    public var traceEndpoint: URL? {
        configuration.traceEndpoint
    }

    /// Defines an optional custom session replay endpoint to which all session replay data will be sent to.
    @objc
    public var sessionReplayEndpoint: URL? {
        configuration.sessionReplayEndpoint
    }


    // MARK: - Initialization

    /// Initialize the endpoint configuration with the Splunk RUM realm and RUM access token.
    ///
    /// - Parameters:
    ///   - realm: A Splunk RUM realm to which all instrumentation will be sent to.
    ///   - rumAccessToken: A required RUM access token to authenticate requests with the RUM instrumentation collector.
    @objc
    public convenience init(realm: String, rumAccessToken: String) {
        let endpointConfiguration = EndpointConfiguration(
            realm: realm,
            rumAccessToken: rumAccessToken
        )

        self.init(for: endpointConfiguration)
    }

    /// Initialize the endpoint configuration with a custom trace url and an optional session replay url.
    ///
    /// - Parameters:
    ///   - trace: A trace URL to which all traces will be sent to.
    ///   - sessionReplay: An optional session replay URL, to which session replay data will be sent to. Required if session replay functionality is enabled.
    @objc
    public convenience init(trace: URL, sessionReplay: URL? = nil) {
        let endpointConfiguration = EndpointConfiguration(
            trace: trace,
            sessionReplay: sessionReplay
        )

        self.init(for: endpointConfiguration)
    }


    // MARK: - Conversion utils

    init(for endpointConfiguration: EndpointConfiguration) {
        // Initialize according to the native Swift variant
        configuration = endpointConfiguration
    }

    func endpointConfiguration() -> EndpointConfiguration {
        // We return a native variant for Swift language
        configuration
    }
}
