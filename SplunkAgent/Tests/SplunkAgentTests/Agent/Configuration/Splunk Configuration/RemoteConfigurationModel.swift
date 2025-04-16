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

// MARK: - Temporary module configuration models for basic structural tests.

struct RemoteConfigurationTestModel: Codable {
    let configuration: MRUMConfigurationRootTestModel
}

struct MRUMConfigurationRootTestModel: Codable {
    let mrum: MRUMConfigurationTestModel
}

struct MRUMConfigurationTestModel: Codable {
    let enabled: Bool
    let maxSessionLength: Double
    let sessionTimeout: Double
    
    let sessionReplay: SessionReplayTestConfigurationModel
    let crashReporting: CrashReportsTestConfigurationModel
    let networkTracing: NetworkTracingTestConfigurationModel
    let slowFrameDetector: ANRReportsTestConfigurationModel
    let appStart: AppStartTestConfigurationModel
}

struct SessionReplayTestConfigurationModel: Codable {
    let enabled: Bool
}

struct CrashReportsTestConfigurationModel: Codable {
    let enabled: Bool
}

struct AppStartTestConfigurationModel: Codable {
    let enabled: Bool
}

struct ANRReportsTestConfigurationModel: Codable {
    let enabled: Bool
    let slowFrameDetectorThresholdMilliseconds: Double
    let frozenFrameDetectorThresholdMilliseconds: Double
}

struct NetworkTracingTestConfigurationModel: Codable {
    let enabled: Bool
}
