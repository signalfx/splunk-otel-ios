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

import Foundation
import SplunkCommon

/// Configuration for the app hang monitor.
public struct AppHangMonitorConfiguration: ModuleConfiguration {

    // MARK: - Public

    /// Whether app hang monitoring is enabled. It is disabled by default while its overhead is evaluated.
    public var isEnabled: Bool

    /// The minimum continuous main-run-loop busy duration, in milliseconds, that produces a hang span.
    public var thresholdMilliseconds: Int

    /// Whether to attach recent, coarse interaction timing when available.
    public var interactionAssociationEnabled: Bool

    /// The maximum age, in milliseconds, for interaction evidence associated with an episode.
    public var interactionAssociationWindowMilliseconds: Int


    // MARK: - Initialization

    /// Creates app hang monitor configuration.
    ///
    /// - Parameters:
    ///   - isEnabled: Enables monitoring. Defaults to `false` until production overhead is validated.
    ///   - thresholdMilliseconds: Minimum main-run-loop busy duration in milliseconds. Defaults to `250`.
    ///   - interactionAssociationEnabled: Includes recent interaction timing when available. Defaults to `true`.
    ///   - interactionAssociationWindowMilliseconds: Maximum age for recent interaction evidence. Defaults to `5000`.
    public init(
        isEnabled: Bool = false,
        thresholdMilliseconds: Int = 250,
        interactionAssociationEnabled: Bool = true,
        interactionAssociationWindowMilliseconds: Int = 5_000
    ) {
        self.isEnabled = isEnabled
        self.thresholdMilliseconds = thresholdMilliseconds
        self.interactionAssociationEnabled = interactionAssociationEnabled
        self.interactionAssociationWindowMilliseconds = interactionAssociationWindowMilliseconds
    }
}
