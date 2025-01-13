//
//  MRUM SDK, © 2024 CISCO
//

import Foundation
import MRUMSharedProtocols
import OpenTelemetryApi
import OpenTelemetrySdk

/// Builds OTel Resource object from AgentResources.
extension Resource {

    /// Merges Resource object with AgentResources.
    mutating func merge(with agentResources: AgentResources) {

        // Service info
        let serviceName = agentResources.appName
        let serviceVersion = Resource.serviceVersion(
            fromAppVersion: agentResources.appVersion,
            appBuild: agentResources.appBuild
        )
        
        // Agent info
        let agentVersion = agentResources.agentVersion

        // Device info
        let deviceModelIdentifier = agentResources.deviceModelIdentifier
        let deviceManufacturer = agentResources.deviceManufacturer
        let deviceID = agentResources.deviceID
        
        // OS info
        // ⚠️⚠️⚠️ osName hardcoded right now because platform does not accept other variations, like iPadOS
        let osName = "iOS"
//        let osName = agentResources.osName
        let osVersion = agentResources.osVersion
        let osDescription = agentResources.osDescription
        let osType = agentResources.osType
        
        // Build required attributes
        let requiredAttributes: [String: AttributeValue] = [

            // Service info
            ResourceAttributes.serviceName.rawValue: AttributeValue.string(serviceName),
            ResourceAttributes.serviceVersion.rawValue: AttributeValue.string(serviceVersion),

            // SDK info
            "com.appdynamics.agent.version": AttributeValue.string(agentVersion),

            // Device info
            ResourceAttributes.deviceModelIdentifier.rawValue: AttributeValue.string(deviceModelIdentifier),
            ResourceAttributes.deviceManufacturer.rawValue: AttributeValue.string(deviceManufacturer),
            ResourceAttributes.deviceId.rawValue: AttributeValue.string(deviceID),

            // OS info
            ResourceAttributes.osName.rawValue: AttributeValue.string(osName),
            ResourceAttributes.osVersion.rawValue: AttributeValue.string(osVersion),
            ResourceAttributes.osDescription.rawValue: AttributeValue.string(osDescription),
            ResourceAttributes.osType.rawValue: AttributeValue.string(osType),
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
