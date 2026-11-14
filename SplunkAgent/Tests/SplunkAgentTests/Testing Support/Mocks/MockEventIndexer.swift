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

@testable import SplunkAgent

/// An event indexer that is either ready and gives every event index 0, or never ready.
final class MockEventIndexer: EventIndexer {

    let name = "mock"

    let isReady: Bool

    init(isReady: Bool) {
        self.isReady = isReady
    }

    func prepareIndex(sessionId _: String, eventTimestamp _: Date) -> Int {
        0
    }

    func removeIndex(sessionId _: String, eventTimestamp _: Date) {}
}
