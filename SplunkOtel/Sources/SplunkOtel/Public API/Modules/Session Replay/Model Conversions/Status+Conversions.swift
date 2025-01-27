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
@_implementationOnly import CiscoSessionReplay

typealias SplunkSessionReplayStatus = CiscoSessionReplay.Status

// Internal extension to convert `Status` proxy model to the underlying SessionReplay's `Status` model
extension SessionReplayStatus {

    // MARK: - Computed properties

    var srStatus: SplunkSessionReplayStatus {

        switch self {
        case .recording:
            return .recording

        case .notRecording(.diskCacheCapacityOverreached):
            return .notRecording(.diskCacheCapacityOverreached)

        case .notRecording(.internalError):
            return .notRecording(.internalError)

        case .notRecording(.notStarted):
            return .notRecording(.notStarted)

        case .notRecording(.projectLimitReached):
            // TODO: validate - this changed from .projectLimitReached
            return .notRecording(.notStarted)

        case .notRecording(.stopped):
            return .notRecording(.stopped)

        case .notRecording(.swiftUIPreviewContext):
            return .notRecording(.swiftUIPreviewContext)

        case .notRecording(.unsupportedPlatform):
            return .notRecording(.unsupportedPlatform)

        case .notRecording(.remotelyDisabled):
            return .notRecording(.notStarted)
        }
    }
}


extension SessionReplayStatus {

    init(srStatus: SplunkSessionReplayStatus) {

        switch srStatus {
        case .recording:
            self = .recording

        case .notRecording(.diskCacheCapacityOverreached):
            self = .notRecording(.diskCacheCapacityOverreached)

        case .notRecording(.internalError):
            self = .notRecording(.internalError)

        case .notRecording(.notStarted):
            self = .notRecording(.notStarted)

        // TODO: validate - this changed from .projectLimitReached
        // case .notRecording(.projectLimitReached):
        //    self = .notRecording(.projectLimitReached)

        case .notRecording(.stopped):
            self = .notRecording(.stopped)

        case .notRecording(.swiftUIPreviewContext):
            self = .notRecording(.swiftUIPreviewContext)

        case .notRecording(.unsupportedPlatform):
            self = .notRecording(.unsupportedPlatform)
        }
    }
}
