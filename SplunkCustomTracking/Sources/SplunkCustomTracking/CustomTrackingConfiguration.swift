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
import SplunkSharedProtocols


// MARK: - CustomTrackingConfiguration

public struct CustomTrackingConfiguration: ModuleConfiguration {
    

    // MARK: - Public Properties

    /// Whether tracking is enabled
    public var enabled: Bool

    /// Maximum number of tracked items to store in memory
    public var maxBufferSize: Int

    /// Maximum time in seconds to hold tracked items before forcing emission
    public var maxBufferAge: TimeInterval


    // MARK: Initialization

    public init(
        enabled: Bool,
        maxBufferSize: Int = 100,
        maxBufferAge: TimeInterval = 60.0
    ) {
        self.enabled = enabled
        self.maxBufferSize = maxBufferSize
        self.maxBufferAge = maxBufferAge
    }
}
