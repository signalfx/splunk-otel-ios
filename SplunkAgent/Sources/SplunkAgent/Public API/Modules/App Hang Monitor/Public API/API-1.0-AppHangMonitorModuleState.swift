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

/// Provides the current state and configured threshold of the app hang monitor.
public protocol AppHangMonitorModuleState {

    // MARK: - State

    /// Whether app hang monitoring is enabled by configuration.
    var isEnabled: Bool { get }

    /// Whether monitoring is paused, including while the app is inactive.
    var isPaused: Bool { get }

    /// The configured main-run-loop busy threshold in milliseconds.
    var thresholdMilliseconds: Int { get }
}
