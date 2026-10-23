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

internal import SplunkAppHangMonitor

/// Operational public API proxy for app hang monitoring.
final class AppHangMonitor: AppHangMonitorModule, AppHangMonitorModuleState {

    // MARK: - Internal

    unowned let module: SplunkAppHangMonitor.AppHangMonitor


    // MARK: - State

    var state: any AppHangMonitorModuleState {
        self
    }

    var isEnabled: Bool {
        module.isEnabled
    }

    var isPaused: Bool {
        module.isPaused
    }

    var thresholdMilliseconds: Int {
        module.thresholdMilliseconds
    }


    // MARK: - Monitoring controls

    func pause() {
        module.pause()
    }

    func resume() {
        module.resume()
    }


    // MARK: - Initialization

    init(for module: SplunkAppHangMonitor.AppHangMonitor) {
        self.module = module
    }
}
