//
/*
Copyright 2022 Splunk Inc.

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

import XCTest
@testable import SplunkRum

func ns(_ ms: UInt64) -> UInt64 {
    ms * 1_000_000
}

class BandwidthTrackerTest: XCTestCase {

    func testMeasure() throws {
        let tracker = BandwidthTracker(timeWindowMillis: 5_000)
        XCTAssertEqual(tracker.bandwidth(timeNanosNow: ns(0)), 0.0)
        tracker.add(bytes: 1024, timeNanos: ns(1_000))
        XCTAssertEqual(tracker.bandwidth(timeNanosNow: ns(1_000)), 1.0)
        tracker.add(bytes: 1024, timeNanos: ns(2_000))
        XCTAssertEqual(tracker.bandwidth(timeNanosNow: ns(2_000)), 1.0)
        XCTAssertEqual(tracker.bandwidth(timeNanosNow: ns(3_000)), 2 / 3, accuracy: 0.01)
        // The first byte sample should be discarded - only 1024 bytes transferred in the last 5 seconds
        XCTAssertEqual(tracker.bandwidth(timeNanosNow: ns(6_500)), 0.2048, accuracy: 0.01)
    }

    func testMaxSamples() {
        let tracker = BandwidthTracker(timeWindowMillis: 6_000, maxSamples: 3)
        tracker.add(bytes: 8192, timeNanos: ns(0))
        tracker.add(bytes: 2048, timeNanos: ns(1_000))
        tracker.add(bytes: 2048, timeNanos: ns(2_000))
        tracker.add(bytes: 2048, timeNanos: ns(3_000))
        XCTAssertEqual(tracker.bandwidth(timeNanosNow: ns(6_000)), 1.0, accuracy: 0.01)
    }

}
