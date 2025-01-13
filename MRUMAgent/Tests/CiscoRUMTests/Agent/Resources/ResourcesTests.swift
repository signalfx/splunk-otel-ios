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

@testable import OpenTelemetrySdk
@testable import CiscoRUM
@testable import MRUMOTel
@testable import MRUMSharedProtocols
import XCTest


/// Tests Resource Attributes parameters based on `EUM Mobile Agents OTel Specification` article.
final class ResourcesTests: XCTestCase {

    func testRequiredResources() throws {
        // Agent initialization
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let agent = try AgentTestBuilder.build(with: configuration)
        agent.eventManager = DefaultEventManager(with: configuration, agent: agent)

        // Get stored resources
        let eventManager = try XCTUnwrap(agent.eventManager as? DefaultEventManager)
        let logEventProcessor = try XCTUnwrap(eventManager.logEventProcessor as? OTLPLogEventProcessor)
        let otelResource = try XCTUnwrap(logEventProcessor.resource)

        // Test service name
        let serviceName = try XCTUnwrap(otelResource.attributes[ResourceAttributes.serviceName.rawValue])
        XCTAssertFalse(serviceName.description.isEmpty)

        // Test service version
        let serviceVersion = try XCTUnwrap(otelResource.attributes[ResourceAttributes.serviceVersion.rawValue])
        XCTAssertFalse(serviceVersion.description.isEmpty)

        // Test telemetry sdk name
        let telemetrySdkName = try XCTUnwrap(otelResource.attributes[ResourceAttributes.telemetrySdkName.rawValue])
        XCTAssertFalse(telemetrySdkName.description.isEmpty)

        // Test telemetry sdk language
        let telemetrySdkLanguage = try XCTUnwrap(otelResource.attributes[ResourceAttributes.telemetrySdkLanguage.rawValue])
        XCTAssertFalse(telemetrySdkLanguage.description.isEmpty)

        // Test telemetry sdk version
        let telemetrySdkVersion = try XCTUnwrap(otelResource.attributes[ResourceAttributes.telemetrySdkVersion.rawValue])
        XCTAssertFalse(telemetrySdkVersion.description.isEmpty)

        // Test device ID
        let deviceID = try XCTUnwrap(otelResource.attributes[ResourceAttributes.deviceId.rawValue])
        XCTAssertFalse(deviceID.description.isEmpty)

        // Test device model identifier
        let deviceModelIdentifier = try XCTUnwrap(otelResource.attributes[ResourceAttributes.deviceModelIdentifier.rawValue])
        XCTAssertFalse(deviceModelIdentifier.description.isEmpty)

        // Test device manufacturer
        let deviceManufacturer = try XCTUnwrap(otelResource.attributes[ResourceAttributes.deviceManufacturer.rawValue])
        XCTAssertFalse(deviceManufacturer.description.isEmpty)

        // Test os name
        let osName = try XCTUnwrap(otelResource.attributes[ResourceAttributes.osName.rawValue])
        XCTAssertFalse(osName.description.isEmpty)

        // Test os version
        let osVersion = try XCTUnwrap(otelResource.attributes[ResourceAttributes.osVersion.rawValue])
        XCTAssertFalse(osVersion.description.isEmpty)

        // Test os description
        let osDescription = try XCTUnwrap(otelResource.attributes[ResourceAttributes.osDescription.rawValue])
        XCTAssertFalse(osDescription.description.isEmpty)

        // Test os type
        let osType = try XCTUnwrap(otelResource.attributes[ResourceAttributes.osType.rawValue])
        XCTAssertFalse(osType.description.isEmpty)

        // Test agent version
        let agentVersion = try XCTUnwrap(otelResource.attributes["com.appdynamics.agent.version"])
        XCTAssertFalse(agentVersion.description.isEmpty)
    }
}
