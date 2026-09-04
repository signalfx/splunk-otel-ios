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

import OpenTelemetryApi
import XCTest

@testable import OpenTelemetrySdk
@testable import SplunkAgent
@testable import SplunkCommon
@testable import SplunkOpenTelemetry

/// Tests Resource Attributes parameters based on `EUM Mobile Agents OTel Specification` article.
final class ResourcesTests: XCTestCase {

    func testRequiredResources() throws {
        // Agent initialization
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let agent = try AgentTestBuilder.build(with: configuration)
        agent.eventManager = try DefaultEventManager(with: configuration, agent: agent)

        // Get stored resources
        let eventManager = try XCTUnwrap(agent.eventManager as? DefaultEventManager)
        let logEventProcessor = try XCTUnwrap(eventManager.logEventProcessor as? OTLPLogToSpanEventProcessor)
        let otelResource = try XCTUnwrap(logEventProcessor.resource)

        // Test service name
        let serviceName = try XCTUnwrap(otelResource.attributes[SemanticConventions.Service.name.rawValue])
        XCTAssertFalse(serviceName.description.isEmpty)

        // Test deployment environment
        let deploymentEnvironment = try XCTUnwrap(
            otelResource.attributes[SemanticConventions.Deployment.environmentName.rawValue]
        )
        XCTAssertEqual(deploymentEnvironment, .string(configuration.deploymentEnvironment))
        XCTAssertNil(otelResource.attributes["deployment.environment"])

        // Test telemetry sdk name
        let telemetrySdkName = try XCTUnwrap(otelResource.attributes[SemanticConventions.Telemetry.sdkName.rawValue])
        XCTAssertFalse(telemetrySdkName.description.isEmpty)

        // Test telemetry sdk language
        let telemetrySdkLanguage = try XCTUnwrap(otelResource.attributes[SemanticConventions.Telemetry.sdkLanguage.rawValue])
        XCTAssertFalse(telemetrySdkLanguage.description.isEmpty)

        // Test telemetry sdk version
        let telemetrySdkVersion = try XCTUnwrap(otelResource.attributes[SemanticConventions.Telemetry.sdkVersion.rawValue])
        XCTAssertFalse(telemetrySdkVersion.description.isEmpty)

        // Test device ID
        let deviceID = try XCTUnwrap(otelResource.attributes[SemanticConventions.Device.id.rawValue])
        XCTAssertFalse(deviceID.description.isEmpty)

        // Test device model identifier
        let deviceModelIdentifier = try XCTUnwrap(otelResource.attributes[SemanticConventions.Device.modelIdentifier.rawValue])
        XCTAssertFalse(deviceModelIdentifier.description.isEmpty)

        // Test device manufacturer
        let deviceManufacturer = try XCTUnwrap(otelResource.attributes[SemanticConventions.Device.manufacturer.rawValue])
        XCTAssertFalse(deviceManufacturer.description.isEmpty)

        // Test os name
        let osName = try XCTUnwrap(otelResource.attributes[SemanticConventions.Os.name.rawValue])
        XCTAssertFalse(osName.description.isEmpty)

        // Test os version
        let osVersion = try XCTUnwrap(otelResource.attributes[SemanticConventions.Os.version.rawValue])
        XCTAssertFalse(osVersion.description.isEmpty)

        // Test os description
        let osDescription = try XCTUnwrap(otelResource.attributes[SemanticConventions.Os.description.rawValue])
        XCTAssertFalse(osDescription.description.isEmpty)

        // Test os type
        let osType = try XCTUnwrap(otelResource.attributes[SemanticConventions.Os.type.rawValue])
        XCTAssertFalse(osType.description.isEmpty)

        // Test agent version
        let agentVersion = try XCTUnwrap(otelResource.attributes["rum.sdk.version"])
        XCTAssertFalse(agentVersion.description.isEmpty)
    }

    func testPreviousAppVersionIsIncludedWhenPresent() {
        var resource = Resource()
        let resources = DefaultResources(
            appName: "Tests",
            appVersion: "5.2.0",
            appPreviousVersion: "5.1.3",
            appBuild: "1",
            appDeploymentEnvironment: "test",
            agentHybridType: nil,
            agentVersion: "1.0.0",
            deviceID: "device",
            deviceModelIdentifier: "iPhone",
            deviceManufacturer: "Apple",
            osName: "iOS",
            osVersion: "18.0",
            osDescription: "iOS 18.0",
            osType: "darwin"
        )

        resource.merge(with: resources)

        XCTAssertEqual(resource.attributes["app.version"], .string("5.2.0"))
        XCTAssertEqual(resource.attributes["app.previous_version"], .string("5.1.3"))
    }

    func testPreviousAppVersionIsOmittedWhenAbsentOrEmpty() {
        for previousVersion in [nil, ""] as [String?] {
            var resource = Resource()
            let resources = DefaultResources(
                appName: "Tests",
                appVersion: "5.2.0",
                appPreviousVersion: previousVersion,
                appBuild: "1",
                appDeploymentEnvironment: "test",
                agentHybridType: nil,
                agentVersion: "1.0.0",
                deviceID: "device",
                deviceModelIdentifier: "iPhone",
                deviceManufacturer: "Apple",
                osName: "iOS",
                osVersion: "18.0",
                osDescription: "iOS 18.0",
                osType: "darwin"
            )

            resource.merge(with: resources)

            XCTAssertNil(resource.attributes["app.previous_version"])
        }
    }

    func testPreviousAppVersionReachesErrorResourceAfterUpgrade() throws {
        let storage = UserDefaultsStorage()
        try? storage.delete(forKey: AppInstallationStorage.installationIdKey)
        try? storage.delete(forKey: AppVersionTracker.storageKey)
        defer {
            try? storage.delete(forKey: AppInstallationStorage.installationIdKey)
            try? storage.delete(forKey: AppVersionTracker.storageKey)
        }

        var firstConfiguration = try ConfigurationTestBuilder.buildDefault()
        firstConfiguration.appVersion = "5.1.3"
        let firstAgent = try AgentTestBuilder.build(with: firstConfiguration)
        firstAgent.eventManager = try DefaultEventManager(with: firstConfiguration, agent: firstAgent)

        let firstEventManager = try XCTUnwrap(firstAgent.eventManager as? DefaultEventManager)
        let firstLogEventProcessor = try XCTUnwrap(
            firstEventManager.logEventProcessor as? OTLPLogToSpanEventProcessor
        )
        XCTAssertNil(firstLogEventProcessor.resource?.attributes["app.previous_version"])

        var upgradedConfiguration = firstConfiguration
        upgradedConfiguration.appVersion = "5.2.0"
        let upgradedAgent = try AgentTestBuilder.build(with: upgradedConfiguration)
        upgradedAgent.eventManager = try DefaultEventManager(with: upgradedConfiguration, agent: upgradedAgent)

        let upgradedEventManager = try XCTUnwrap(upgradedAgent.eventManager as? DefaultEventManager)
        let upgradedLogEventProcessor = try XCTUnwrap(
            upgradedEventManager.logEventProcessor as? OTLPLogToSpanEventProcessor
        )
        let upgradedResource = try XCTUnwrap(upgradedLogEventProcessor.resource)

        XCTAssertEqual(upgradedResource.attributes["app.version"], .string("5.2.0"))
        XCTAssertEqual(upgradedResource.attributes["app.previous_version"], .string("5.1.3"))
        XCTAssertEqual(
            firstAgent.runtimeAttributes.all["app.installation.id"] as? String,
            upgradedAgent.runtimeAttributes.all["app.installation.id"] as? String
        )
    }
}
