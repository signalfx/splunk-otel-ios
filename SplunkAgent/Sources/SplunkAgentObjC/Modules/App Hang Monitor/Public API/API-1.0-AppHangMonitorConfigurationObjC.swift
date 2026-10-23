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

/// Configuration for the app hang monitor.
@objc(SPLKAppHangMonitorConfiguration)
@objcMembers
public final class AppHangMonitorConfigurationObjC: ModuleConfigurationObjC {

    // MARK: - Public

    /// Main-run-loop busy duration required to report a hang, in milliseconds.
    ///
    /// Defaults to `250`.
    public var thresholdMilliseconds: Int = 250

    /// Whether recent interaction timing is attached when available.
    ///
    /// Defaults to `true`.
    public var interactionAssociationEnabled = true

    /// Maximum age for interaction evidence, in milliseconds.
    ///
    /// Defaults to `5000`.
    public var interactionAssociationWindowMilliseconds: Int = 5_000


    // MARK: - Initialization

    /// Creates a disabled app hang monitor configuration.
    override public init() {
        super.init()
        isEnabled = false
    }

    /// Creates app hang monitor configuration with the supplied settings.
    ///
    /// - Parameters:
    ///   - isEnabled: Enables monitoring. Defaults to `false` until production overhead is validated.
    ///   - thresholdMilliseconds: Main-run-loop busy duration threshold. Defaults to `250`.
    ///   - interactionAssociationEnabled: Attaches recent interaction timing when available.
    ///   - interactionAssociationWindowMilliseconds: Maximum age for interaction evidence. Defaults to `5000`.
    @objc(initWithEnabled:thresholdMilliseconds:interactionAssociationEnabled:interactionAssociationWindowMilliseconds:)
    public init(
        isEnabled: Bool = false,
        thresholdMilliseconds: Int = 250,
        interactionAssociationEnabled: Bool = true,
        interactionAssociationWindowMilliseconds: Int = 5_000
    ) {
        super.init()
        self.isEnabled = isEnabled
        self.thresholdMilliseconds = thresholdMilliseconds
        self.interactionAssociationEnabled = interactionAssociationEnabled
        self.interactionAssociationWindowMilliseconds = interactionAssociationWindowMilliseconds
    }
}
