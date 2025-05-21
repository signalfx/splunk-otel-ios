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
import OpenTelemetryApi
import OpenTelemetrySdk
import SplunkCommon

/// Builds OTel Resource object from AgentResources.
extension Resource {

    /// Merges Resource object with AgentResources.
    mutating func merge(with agentResources: AgentResources) {

        // Build required attributes
        let requiredAttributes: [String: AttributeValue] = [

            // App info
            ResourceAttributes.deploymentEnvironment.rawValue: .string(agentResources.appDeploymentEnvironment),
            "app": .string(agentResources.appName),
            "app.version": .string(agentResources.appVersion),

            // SDK info
            "rum.sdk.version": .string(agentResources.agentVersion),

            // Device info
            ResourceAttributes.deviceModelIdentifier.rawValue: .string(agentResources.deviceModelIdentifier),
            ResourceAttributes.deviceManufacturer.rawValue: .string(agentResources.deviceManufacturer),
            ResourceAttributes.deviceId.rawValue: .string(agentResources.deviceID),

            ResourceAttributes.deviceModelName.rawValue: .string(agentResources.deviceModelIdentifier),

            // OS info
            ResourceAttributes.osName.rawValue: .string(agentResources.osName),
            ResourceAttributes.osVersion.rawValue: .string(agentResources.osVersion),
            ResourceAttributes.osDescription.rawValue: .string(agentResources.osDescription),
            ResourceAttributes.osType.rawValue: .string(agentResources.osType)
        ]

        // Add required attributes to the resource
        merge(other: Resource(attributes: requiredAttributes))

        // Add optional hybrid agent type
        if let hybridType = agentResources.agentHybridType {
            let attribute = ["appdynamics.agent.hybrid_type": AttributeValue.string(hybridType)]
            merge(other: Resource(attributes: attribute))
        }
    }

    private static func serviceVersion(fromAppVersion appVersion: String, appBuild: String) -> String {
        return "\(appVersion) (\(appBuild))"
    }
}
