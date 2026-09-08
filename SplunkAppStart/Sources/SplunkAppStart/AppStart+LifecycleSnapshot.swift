//
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

import Foundation

extension AppStart {

    /// Validates optional lifecycle events supplied by a hybrid integration.
    func validSnapshotEventTimes(end: Date) -> Bool {
        if let processStartTimestamp,
            let didFinishLaunchingTimestamp,
            processStartTimestamp > didFinishLaunchingTimestamp
        {
            return false
        }

        if let processStartTimestamp,
            let willEnterForegroundTimestamp,
            processStartTimestamp > willEnterForegroundTimestamp
        {
            return false
        }

        if let didFinishLaunchingTimestamp,
            didFinishLaunchingTimestamp > end
        {
            return false
        }

        if let willEnterForegroundTimestamp,
            willEnterForegroundTimestamp > end
        {
            return false
        }

        if let didFinishLaunchingTimestamp,
            let willEnterForegroundTimestamp,
            didFinishLaunchingTimestamp > willEnterForegroundTimestamp
        {
            return false
        }

        return true
    }
}
