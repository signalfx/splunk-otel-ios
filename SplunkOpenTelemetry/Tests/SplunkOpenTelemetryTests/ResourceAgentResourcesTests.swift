//
/*
Copyright 2026 Splunk Inc.

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
import OpenTelemetrySdk
import SplunkCommon
import Testing

@testable import SplunkOpenTelemetry

struct ResourceAgentResourcesTests {
    @Test
    func usesDeploymentEnvironmentName() {
        var resource = Resource()

        resource.merge(with: TestAgentResources())

        #expect(resource.attributes["deployment.environment.name"] == .string("production"))
        #expect(resource.attributes["deployment.environment"] == nil)
    }
}

private struct TestAgentResources: AgentResources {
    let appName = "TestApp"
    let appVersion = "1.0"
    let appBuild = "1"
    let appDeploymentEnvironment = "production"
    let agentHybridType: String? = nil
    let agentVersion = "test"
    let deviceModelIdentifier = "test-device"
    let deviceManufacturer = "Apple"
    let deviceID = "test-device-id"
    let osName = "iOS"
    let osVersion = "test-os"
    let osDescription = "test-os-description"
    let osType = "darwin"
}
