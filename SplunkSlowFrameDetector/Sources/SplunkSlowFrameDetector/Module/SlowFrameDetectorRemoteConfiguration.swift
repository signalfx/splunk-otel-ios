//
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
import SplunkCommon

/// SlowFrameDetector module remote configuration.
public struct SlowFrameDetectorRemoteConfiguration: RemoteModuleConfiguration {

    // MARK: - Module management

    /// A boolean value that indicates whether the Slow Frame Detector module is enabled or disabled through remote settings.
    public var enabled: Bool = true


    // MARK: - Initialization

    /// Initializes the remote configuration from raw data.
    ///
    /// - Note: This initializer is currently a placeholder and does not parse the provided data.
    /// - Parameter data: The raw `Data` from the remote configuration source. This parameter is ignored.
    public init?(from data: Data) {}
}
