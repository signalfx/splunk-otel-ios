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

/// Endpoint configuration defines a destination for all instrumentation.
///
/// Can be set either by providing the `realm`, which sends all instrumentation to the Splunk RUM collector to a specified realm;
/// or by providing a custom traces and optionally a custom session replay url, to which all instrumentation will be sent to.
public struct EndpointConfiguration: Codable, Equatable {

    // MARK: - Public

    /// Defines a Splunk RUM realm to which all instrumentation will be sent to.
    public let realm: String?

    /// Defines a custom traces endpoint to which all traces will be sent to.
    public let tracesEndpoint: URL?

    /// Defines an optional custom session replay endpoint to which all session replay data will be sent to.
    public let sessionReplayEndpoint: URL?

    /// Initialize the endpoint configuration with the Splunk RUM realm.
    public init(realm: String) {
        guard realm.count > 0 else {
            self.realm = nil
            tracesEndpoint = nil
            sessionReplayEndpoint = nil

            return
        }

        self.realm = realm

        var urlCompoments = URLComponents()
        urlCompoments.scheme = "https"
        urlCompoments.host = "rum-ingest.\(realm).signalfx.com"
        urlCompoments.path = "/v1/rumotlp"

        tracesEndpoint = urlCompoments.url

        // ⚠️ Session replay endpoint not in use atm
        sessionReplayEndpoint = nil
    }

    /// Initialize the endpoint configuration with a custom traces url and an optional session replay url. All traces will be routed to the provided traces url.
    public init(traces: URL, sessionReplay: URL? = nil) {
        realm = nil
        tracesEndpoint = traces
        sessionReplayEndpoint = sessionReplay
    }
}

extension EndpointConfiguration: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return """

            realm: \(realm ?? "nil")
            tracesEndpoint: \(sessionReplayEndpoint?.absoluteString ?? "nil")
            sessionReplayEndpoint: \(sessionReplayEndpoint?.absoluteString ?? "nil")
        """
    }

    public var debugDescription: String {
        return description
    }
}
