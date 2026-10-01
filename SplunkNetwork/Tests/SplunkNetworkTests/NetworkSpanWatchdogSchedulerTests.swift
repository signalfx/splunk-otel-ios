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
import XCTest

@testable import SplunkNetwork

final class NetworkSpanWatchdogSchedulerTests: XCTestCase {

    func testWatchdogExecutesExpiredActionsOffSchedulerQueueInDeadlineOrder() {
        let schedulerQueue = DispatchQueue(label: "NetworkSpanWatchdogSchedulerTests.scheduler")
        let schedulerQueueKey = DispatchSpecificKey<Void>()
        schedulerQueue.setSpecific(key: schedulerQueueKey, value: ())
        let scheduler = NetworkSpanWatchdogScheduler(
            queue: schedulerQueue,
            tickInterval: 1
        )
        let lock = NSLock()
        var actionOrder: [String] = []
        var actionsRanOffSchedulerQueue = true
        let actionsCompleted = expectation(description: "Watchdog actions completed")
        actionsCompleted.expectedFulfillmentCount = 2

        scheduler.schedule(after: 0.1) {
            lock.lock()
            actionOrder.append("later")
            actionsRanOffSchedulerQueue = actionsRanOffSchedulerQueue && DispatchQueue.getSpecific(key: schedulerQueueKey) == nil
            lock.unlock()
            actionsCompleted.fulfill()
        }
        scheduler.schedule(after: 0.05) {
            lock.lock()
            actionOrder.append("sooner")
            actionsRanOffSchedulerQueue = actionsRanOffSchedulerQueue && DispatchQueue.getSpecific(key: schedulerQueueKey) == nil
            lock.unlock()
            actionsCompleted.fulfill()
        }

        wait(for: [actionsCompleted], timeout: 1)

        lock.lock()
        let recordedOrder = actionOrder
        let recordedQueueResult = actionsRanOffSchedulerQueue
        lock.unlock()
        XCTAssertEqual(recordedOrder, ["sooner", "later"])
        XCTAssertTrue(recordedQueueResult)
    }
}
