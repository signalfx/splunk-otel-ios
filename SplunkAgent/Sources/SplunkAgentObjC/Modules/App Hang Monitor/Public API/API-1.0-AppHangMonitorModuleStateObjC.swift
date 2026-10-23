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
import SplunkAgent

/// The current state of app hang monitoring.
@objc(SPLKAppHangMonitorModuleState)
public final class AppHangMonitorModuleStateObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC


    // MARK: - Monitoring state

    /// Whether app hang monitoring is enabled by configuration.
    @objc
    public var isEnabled: Bool {
        owner.agent.appHangMonitor.state.isEnabled
    }

    /// Whether app hang monitoring is paused, including while the app is inactive.
    @objc
    public var isPaused: Bool {
        owner.agent.appHangMonitor.state.isPaused
    }

    /// The configured main-run-loop busy threshold, in milliseconds.
    @objc
    public var thresholdMilliseconds: Int {
        owner.agent.appHangMonitor.state.thresholdMilliseconds
    }


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
