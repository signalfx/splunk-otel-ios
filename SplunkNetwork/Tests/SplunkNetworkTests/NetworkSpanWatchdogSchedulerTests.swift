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
            queue: schedulerQueue
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

    func testCancelingMiddleEntriesMaintainsDeadlineHeap() {
        let scheduler = NetworkSpanWatchdogScheduler()
        let lock = NSLock()
        var fired: [Int] = []
        let completed = expectation(description: "Remaining watchdog actions completed")
        completed.expectedFulfillmentCount = 2

        let first = scheduler.schedule(after: 0.05) {
            lock.lock()
            fired.append(1)
            lock.unlock()
            completed.fulfill()
        }
        let middle = scheduler.schedule(after: 0.1) {
            lock.lock()
            fired.append(2)
            lock.unlock()
            completed.fulfill()
        }
        let last = scheduler.schedule(after: 0.15) {
            lock.lock()
            fired.append(3)
            lock.unlock()
            completed.fulfill()
        }

        scheduler.cancel(middle)
        XCTAssertEqual(scheduler.pendingCount, 2)

        wait(for: [completed], timeout: 1)

        lock.lock()
        let recorded = fired
        lock.unlock()
        XCTAssertEqual(recorded, [1, 3])
        scheduler.cancel(first)
        scheduler.cancel(last)
    }

    func testCancelingManyInterleavedEntriesMaintainsDeadlineHeap() {
        let scheduler = NetworkSpanWatchdogScheduler()
        let lock = NSLock()
        var fired: [Int] = []
        let entryCount = 40
        let canceledIndices = Set(stride(from: 0, to: entryCount, by: 3))
        let expectedIndices = (0 ..< entryCount).filter { !canceledIndices.contains($0) }
        let completed = expectation(description: "Non-canceled watchdog actions completed")
        completed.expectedFulfillmentCount = expectedIndices.count
        var tokens: [NetworkSpanWatchdogScheduler.Token] = []

        for index in 0 ..< entryCount {
            let token = scheduler.schedule(after: 0.01 + Double(index) * 0.002) {
                lock.lock()
                fired.append(index)
                lock.unlock()
                completed.fulfill()
            }
            tokens.append(token)
        }

        for index in canceledIndices {
            scheduler.cancel(tokens[index])
        }

        wait(for: [completed], timeout: 2)

        lock.lock()
        let recorded = fired
        lock.unlock()
        XCTAssertEqual(recorded, expectedIndices)
        XCTAssertEqual(scheduler.pendingCount, 0)
    }

    func testExtremeDelayDoesNotTrapOrScheduleImmediateAction() {
        let scheduler = NetworkSpanWatchdogScheduler()
        let token = scheduler.schedule(after: .greatestFiniteMagnitude) {}

        XCTAssertEqual(scheduler.pendingCount, 1)
        scheduler.cancel(token)
        XCTAssertEqual(scheduler.pendingCount, 0)
    }
}
