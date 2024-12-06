//
/*
Copyright 2024 Splunk Inc.

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

/// A status of Session Replay recording.
///
/// Describes the possible states for recording in which module can be during its lifecycle.
public enum SessionReplayStatus: Equatable {

    /// Recording has been started and is currently in progress.
    case recording

    /// Recording is not in progress. A ``Cause`` determines the reason for this status.
    case notRecording(Cause)


    /// The cause why the recording is currently not running.
    public enum Cause {
        /// During this application launch, the recording has not yet started.
        case notStarted

        /// The user stopped the previous recording session.
        case stopped

        /// It was impossible to start the recording
        /// because this project reached its limits.
        ///
        /// - Note: Typically it is the number of recorded
        ///         month sessions or other backend metrics.
        case projectLimitReached

        /// It was impossible to start the recording because the internal
        /// database could not be open, or another internal error occurred.
        case internalError

        /// Custom preferences do not allow recording in the SwiftUI Preview context.
        case swiftUIPreviewContext

        /// Recording is not supported on the current platform.
        case unsupportedPlatform

        /// Disk cache overreached its allowed size.
        case diskCacheCapacityOverreached

        /// Disabled by remote configuration.
        case remotelyDisabled
    }
}
