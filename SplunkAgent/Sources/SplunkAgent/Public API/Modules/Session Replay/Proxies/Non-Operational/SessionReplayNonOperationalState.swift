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

/// The class implementing public API for the current state in non-operational mode.
///
/// This is especially the case when the module is stopped by remote configuration,
/// but we still need to keep the API available to the user.
final class SessionReplayNonOperationalState: SessionReplayModuleState {

    // MARK: - Recording

    /// The session replay status when the module is non-operational.
    ///
    /// This property always returns ``SessionReplayStatus/notRecording(_:)`` with a reason of `.notStarted`.
    public var status: SessionReplayStatus {
        .notRecording(.notStarted)
    }

    /// A boolean indicating if recording is active when the module is non-operational.
    ///
    /// This property always returns `false`.
    public var isRecording: Bool {
        false
    }
}
