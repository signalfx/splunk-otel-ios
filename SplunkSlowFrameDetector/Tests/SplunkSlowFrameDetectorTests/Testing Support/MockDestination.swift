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
import SplunkCommon

#if os(iOS) || os(tvOS) || os(visionOS)
    @testable import SplunkSlowFrameDetector

    final class MockDestination: SlowFrameDetectorDestination {
        // This dictionary will store the accumulated counts.
        private var reportedCountsStorage: [String: Int] = [:]
        private var onSend: ((String, Int) -> Void)?
        private let lock = NSLock()

        var reportedCounts: [String: Int] {
            lock.lock()
            defer { lock.unlock() }
            return reportedCountsStorage
        }

        func send(type: String, count: Int, sharedState _: AgentSharedState?) {
            lock.lock()
            reportedCountsStorage[type, default: 0] += count
            let handler = onSend
            lock.unlock()
            handler?(type, count)
        }

        func setOnSend(_ handler: ((String, Int) -> Void)?) {
            lock.lock()
            onSend = handler
            lock.unlock()
        }
    }
#endif
