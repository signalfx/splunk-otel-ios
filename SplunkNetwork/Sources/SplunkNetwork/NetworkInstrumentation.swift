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

    // MARK: - Public

    /// Holds regex patterns from IgnoreURLs API.
    public var ignoreURLs = IgnoreURLs()

    /// Endpoints excluded from network instrumentation.
    public var excludedEndpoints: [URL]?

    /// An instance of the Agent shared state object, which is used to obtain agent's state, e.g. a session id.
    public unowned var sharedState: AgentSharedState?

    public required init() {}

    /// Installs the Network Instrumentation module.
    ///
    /// - Parameters:
    ///   - configuration: Module specific local configuration.
    ///   - remoteConfiguration: Module specific remote configuration.
    public func install(
        with configuration: (any ModuleConfiguration)?,
        remoteConfiguration: (any RemoteModuleConfiguration)?
    ) {
        // Intentionally unused
        _ = remoteConfiguration

        let config = configuration as? Configuration

        // Start the network instrumentation if it's enabled or if no configuration is provided.
        if config?.isEnabled ?? true {

            if let ignoreURLsParameter = config?.ignoreURLs {
                ignoreURLs = ignoreURLsParameter
            }

            initalizeNetworkInstrumentation(module: self)
        }
    }
}
