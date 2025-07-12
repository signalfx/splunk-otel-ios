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

/// An enumeration that represents the detailed lifecycle status of a Session Replay recording.
///
/// You can check this status to understand the current state of the recording.
///
/// ### Example ###
/// ```
/// switch SplunkRum.shared.sessionReplay.state.status {
/// case .recording:
///     print("Session Replay is recording.")
/// case .notRecording(let cause):
///     print("Session Replay is not recording: \(cause)")
/// }
/// ```
public enum SessionReplayStatus: Equatable {

    /// The Session Replay is actively recording.
    case recording

    /// The Session Replay is not recording. The associated `Cause` provides the specific reason.
    case notRecording(Cause)


    /// The reason why the Session Replay status is `.notRecording`.
    public enum Cause {
        /// The recording has not yet been started in the current application session.
        case notStarted

        /// The recording was explicitly stopped by a call to `stop()`.
        case stopped

        /// The recording could not be started or was interrupted due to an internal error, such as a database issue.
        case internalError

        /// The recording is disabled because the application is running in a SwiftUI Preview.
        case swiftUIPreviewContext

        /// Session Replay is not supported on the current operating system or platform.
        case unsupportedPlatform

        /// The recording was stopped because the on-disk storage limit was reached.
        case storageLimitReached
    }
}