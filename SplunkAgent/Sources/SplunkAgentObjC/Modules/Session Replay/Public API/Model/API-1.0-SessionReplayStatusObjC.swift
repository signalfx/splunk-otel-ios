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
import SplunkAgent

/// A status of Session Replay recording.
///
/// Describes the possible states for recording in which module can be during its lifecycle.
@objc(SPLKSessionReplayStatus)
public final class SessionReplayStatusObjC: NSObject {

    // MARK: - Session Replay status

    /// Recording has been started and is currently in progress.
    @objc
    public static let recording = NSNumber(value: 1)

    /// Recording is not in progress because the recording
    /// has not yet started during this application launch.
    @objc
    public static let notRecordingNotStarted = NSNumber(value: -100)

    /// Recording is not supported on the current platform.
    @objc
    public static let notRecordingUnsupportedPlatform = NSNumber(value: -101)

    /// Custom preferences do not allow recording in the SwiftUI Preview context.
    @objc
    public static let notRecordingSwiftUIPreviewContext = NSNumber(value: -101)

    /// Recording is not in progress because the user stopped
    /// the previous recording session.
    @objc
    public static let notRecordingStopped = NSNumber(value: -110)

    /// It was impossible to start the recording because the internal
    /// database could not be open, or another internal error occurred.
    @objc
    public static let notRecordingInternalError = NSNumber(value: -200)

    /// Recording is not in progress because the Disk cache overreached its allowed size.
    @objc
    public static let notRecordingStorageLimitReached = NSNumber(value: -201)


    // MARK: - Initialization

    // Initialization is hidden from the public API
    // as we only need to work with the class type.
    override init() {}


    // MARK: - Conversion utils

    static func status(for value: NSNumber) -> SessionReplayStatus? {
        switch value {
        case recording:
            return .recording

        case notRecordingNotStarted:
            return .notRecording(.notStarted)

        case notRecordingUnsupportedPlatform:
            return .notRecording(.unsupportedPlatform)

        case notRecordingSwiftUIPreviewContext:
            return .notRecording(.swiftUIPreviewContext)

        case notRecordingStopped:
            return .notRecording(.stopped)

        case notRecordingInternalError:
            return .notRecording(.internalError)

        case notRecordingStorageLimitReached:
            return .notRecording(.storageLimitReached)

        default:
            return nil
        }
    }

    static func value(for status: SessionReplayStatus) -> NSNumber {
        switch status {
        case .recording:
            return recording

        case .notRecording(.notStarted):
            return notRecordingNotStarted

        case .notRecording(.unsupportedPlatform):
            return notRecordingUnsupportedPlatform

        case .notRecording(.swiftUIPreviewContext):
            return notRecordingSwiftUIPreviewContext

        case .notRecording(.stopped):
            return notRecordingStopped

        case .notRecording(.internalError):
            return notRecordingInternalError

        case .notRecording(.storageLimitReached):
            return notRecordingStorageLimitReached
        }
    }
}
