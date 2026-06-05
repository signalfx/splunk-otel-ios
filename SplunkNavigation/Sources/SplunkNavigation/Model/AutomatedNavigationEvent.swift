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

import CiscoSwizzling
import Foundation

/// Represents an automatic navigation event.
@_spi(SplunkTesting)
public struct AutomatedNavigationEvent: NavigationActionEvent {

    // MARK: - Public

    public var timestamp: Date
    public var type: NavigationActionEventType
    public var controllerTypeName: String
    public var controllerIdentifier: ObjectIdentifier
    public var navigationControllerIdentifier: ObjectIdentifier? {
        // Required for NavigationActionEvent conformance.
        nil
    }

    public var viewFrame: CGRect?

    public init(
        timestamp: Date,
        type: NavigationActionEventType,
        controllerTypeName: String,
        controllerIdentifier: ObjectIdentifier,
        viewFrame: CGRect? = nil
    ) {
        self.timestamp = timestamp
        self.type = type
        self.controllerTypeName = controllerTypeName
        self.controllerIdentifier = controllerIdentifier
        self.viewFrame = viewFrame
    }
}
