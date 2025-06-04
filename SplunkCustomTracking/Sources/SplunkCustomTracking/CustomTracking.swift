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
import SplunkCommon


public struct CustomTrackingMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}

public struct CustomTrackingData: ModuleEventData {
    public let name: String
    public let attributes: [String: EventAttributeValue]

    public init(name: String, attributes: [String: EventAttributeValue]) {
        self.name = name
        self.attributes = attributes
    }
}


// MARK: - CustomTracking internal module

public final class CustomTrackingInternal {

    public static var instance = CustomTrackingInternal()


    // MARK: - Private Properties

    private let internalLogger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "LogCustomTracking")


    // Shared state
    public unowned var sharedState: AgentSharedState?
    public var onPublishBlock: ((CustomTrackingMetadata, CustomTrackingData) -> Void)?


    // Module conformance
    public required init() {}
}
