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

/// A state object that is representation for the current state of the Agent.
///
/// The individual properties are a combination of:
/// - Default SDK settings.
/// - Initial configuration specified by  ``SPLKAgentConfiguration``.
/// - Settings retrieved from the backend.
///
/// - Note: The states of individual properties in this class can
///         change during the application's runtime.
@objc(SPLKState)
public final class RuntimeStateObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC


    // MARK: - Agent status

    /// A status of agent recording.
    ///
    /// A `NSNumber` which value can be mapped to the `SPLKStatus` constants.
    @objc
    public var status: NSNumber {
        let status = owner.agent.state.status

        return StatusObjC.value(for: status)
    }


    // MARK: - User configuration

    /// A `NSString` that contains the name used for the application identification.
    @objc
    public var appName: String {
        owner.agent.state.appName
    }

    /// A `NSString` that contains the used application version.
    @objc
    public var appVersion: String {
        owner.agent.state.appVersion
    }

    /// An optional `SPLKEndpointConfiguration` containing either the specified realm, or endpoint urls.
    @objc
    public var endpointConfiguration: EndpointConfigurationObjC? {
        guard let configuration = owner.agent.state.endpointConfiguration else {
            return nil
        }

        return EndpointConfigurationObjC(for: configuration)
    }

    /// A `NSString` containing the used application deployment environment.
    @objc
    public var deploymentEnvironment: String {
        owner.agent.state.deploymentEnvironment
    }

    /// A `BOOL` value determining whether the debug logging has been enabled.
    @objc
    public var isDebugLoggingEnabled: Bool {
        owner.agent.state.isDebugLoggingEnabled
    }


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
