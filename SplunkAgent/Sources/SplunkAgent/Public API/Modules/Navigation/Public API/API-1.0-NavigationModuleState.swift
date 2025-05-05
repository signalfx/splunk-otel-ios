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

/// Defines a public API for the current state of the `Navigation` module.
///
/// The individual properties are a combination of:
/// - Default settings.
/// - Initial default configuration.
/// - Settings retrieved from the backend.
/// - Preferred behavior.
///
/// - Note: The states of individual properties in this class can
///         and usually also change during the application's runtime.
public protocol NavigationModuleState {

    // MARK: - Automated tracking

    /// Indicates whether automatic navigation detection is enabled.
    ///
    /// The default value is `false`.
    var isAutomatedTrackingEnabled: Bool { get }
}
