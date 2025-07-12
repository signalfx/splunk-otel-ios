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

/// An interface for the module that detects and reports slow and frozen frames in the user interface.
///
/// ### Example ###
/// ```
/// if SplunkRum.shared.slowFrames.state.isEnabled {
///     print("Slow frame detection is active.")
/// }
/// ```
public protocol SlowFrameDetectorModule {
    /// An object that provides read-only access to the current state of the slow frame detector.
    ///
    /// See ``SlowFrameDetectorModuleState`` for more details.
    var state: any SlowFrameDetectorModuleState { get }
}