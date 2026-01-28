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

internal import SplunkSlowFrameDetector

/// The class implementing SlowFrameDetector public API.
final class SlowFrameDetector: SlowFrameDetectorModule, SlowFrameDetectorModuleState {

    // MARK: - Internal

    unowned let module: SplunkSlowFrameDetector.SlowFrameDetector

    // MARK: - SlowFrameDetectorModuleState Conformance

    /// Returns self as the state provider.
    var state: any SlowFrameDetectorModuleState {
        self
    }

    // MARK: - SlowFrameDetectorModule Conformance

    /// The enabled status of the underlying module.
    var isEnabled: Bool {
        module.isEnabled
    }

    // MARK: - InitializationSplunkSlowFrameDetector.SlowFrameDetector.configuration

    init(for module: SplunkSlowFrameDetector.SlowFrameDetector) {
        self.module = module
    }
}
