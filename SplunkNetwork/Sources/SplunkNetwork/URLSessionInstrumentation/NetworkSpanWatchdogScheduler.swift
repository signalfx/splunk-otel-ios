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
import SplunkCommon

/// Runs network span watchdog callbacks from one shared timer.
///
/// Completed requests are removed from `entries` immediately, so the scheduler retains only
/// requests that are still waiting for a terminal URLSession signal.
///
/// The deadline heap uses one bounded entry per currently open request instead of one delayed
/// work item per request. This keeps completed-request memory bounded by the active set while
/// avoiding a polling scan or a backlog of canceled work items.
///
/// The unchecked sendability is safe because all mutable scheduler state (`entries`, the deadline
/// heap, and its token indexes) is accessed only on `queue`; `schedule`, `cancel`, and timer
/// callbacks synchronously serialize access to that queue. Expired actions are then transferred to
/// `actionQueue`, so scheduled actions must be safe to execute asynchronously on that queue and
/// must synchronize any captured mutable state. To remove this escape hatch under Swift 6, the
/// action closure would need to be `@Sendable`, and all captured task/coordinator state would need
/// checked sendability or an explicit actor/lock-backed wrapper.
final class NetworkSpanWatchdogScheduler: @unchecked Sendable {

    typealias Token = UUID

    // MARK: - Private types

    private struct Entry {
        let deadline: UInt64
        let action: () -> Void
    }

    private struct HeapNode {
        let token: Token
        let deadline: UInt64
    }

    // MARK: - Private properties

    private let queue: DispatchQueue
    private let actionQueue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Void>()
    private let timer: DispatchSourceTimer
    private var entries: [Token: Entry] = [:]
    private var deadlineHeap: [HeapNode] = []
    private var heapIndices: [Token: Int] = [:]

    // MARK: - Initialization

    init(
        queue: DispatchQueue = DispatchQueue(
            label: PackageIdentifier.default(named: "NetworkSpanWatchdog"),
            qos: .utility
        ),
        actionQueue: DispatchQueue = DispatchQueue(
            label: PackageIdentifier.default(named: "NetworkSpanWatchdogActions"),
            qos: .utility
        )
    ) {
        self.queue = queue
        self.actionQueue = actionQueue
        queue.setSpecific(key: queueKey, value: ())

        timer = DispatchSource.makeTimerSource(queue: queue)
        timer.setEventHandler { [weak self] in
            self?.expireEntries()
        }
        timer.schedule(deadline: .distantFuture, repeating: .never)
        timer.resume()
    }

    deinit {
        timer.setEventHandler {}
        timer.cancel()
    }

    // MARK: - Internal properties

    var pendingCount: Int {
        sync { entries.count }
    }

    // MARK: - Scheduling

    @discardableResult
    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> Token {
        let token = Token()
        let deadline = deadline(after: delay)

        sync {
            entries[token] = Entry(deadline: deadline, action: action)
            insertHeapNode(HeapNode(token: token, deadline: deadline))
            armTimer()
        }

        return token
    }

    func cancel(_ token: Token) {
        sync {
            guard entries.removeValue(forKey: token) != nil else {
                return
            }

            removeHeapNode(for: token)
            armTimer()
        }
    }

    // MARK: - Private methods

    private func expireEntries() {
        let now = DispatchTime.now().uptimeNanoseconds
        var actions: [() -> Void] = []

        while let node = deadlineHeap.first, node.deadline <= now {
            _ = removeHeapNode(at: 0)
            if let entry = entries.removeValue(forKey: node.token) {
                actions.append(entry.action)
            }
        }

        armTimer()

        guard !actions.isEmpty else {
            return
        }

        actionQueue.async {
            for action in actions {
                action()
            }
        }
    }

    private func armTimer() {
        guard let nextDeadline = deadlineHeap.first?.deadline else {
            timer.schedule(deadline: .distantFuture, repeating: .never)
            return
        }

        if nextDeadline == UInt64.max {
            timer.schedule(deadline: .distantFuture, repeating: .never)
            return
        }

        timer.schedule(
            deadline: DispatchTime(uptimeNanoseconds: nextDeadline),
            repeating: .never
        )
    }

    private func deadline(after delay: TimeInterval) -> UInt64 {
        let now = DispatchTime.now().uptimeNanoseconds
        guard delay.isFinite else {
            return delay.isNaN || delay < 0 ? now : UInt64.max
        }

        let nanosecondsAsDouble = max(0, delay) * 1_000_000_000
        guard nanosecondsAsDouble < Double(UInt64.max) else {
            return UInt64.max
        }

        let nanoseconds = UInt64(nanosecondsAsDouble)
        let (deadline, overflow) = now.addingReportingOverflow(nanoseconds)
        return overflow ? UInt64.max : deadline
    }

    private func insertHeapNode(_ node: HeapNode) {
        deadlineHeap.append(node)
        let index = deadlineHeap.count - 1
        heapIndices[node.token] = index
        siftUp(from: index)
    }

    @discardableResult
    private func removeHeapNode(at index: Int) -> HeapNode {
        let removedNode = deadlineHeap[index]
        let lastNode = deadlineHeap.removeLast()
        heapIndices.removeValue(forKey: removedNode.token)

        guard index < deadlineHeap.count else {
            return removedNode
        }

        deadlineHeap[index] = lastNode
        heapIndices[lastNode.token] = index
        if index > 0,
            deadlineHeap[index].deadline < deadlineHeap[(index - 1) / 2].deadline
        {
            siftUp(from: index)
        }
        else {
            siftDown(from: index)
        }

        return removedNode
    }

    private func removeHeapNode(for token: Token) {
        guard let index = heapIndices[token] else {
            return
        }

        _ = removeHeapNode(at: index)
    }

    private func siftUp(from index: Int) {
        var child = index
        while child > 0 {
            let parent = (child - 1) / 2
            guard deadlineHeap[child].deadline < deadlineHeap[parent].deadline else {
                return
            }

            deadlineHeap.swapAt(child, parent)
            heapIndices[deadlineHeap[child].token] = child
            heapIndices[deadlineHeap[parent].token] = parent
            child = parent
        }
    }

    private func siftDown(from index: Int) {
        var parent = index
        while true {
            let leftChild = parent * 2 + 1
            guard leftChild < deadlineHeap.count else {
                return
            }

            let rightChild = leftChild + 1
            var smallest = leftChild
            if rightChild < deadlineHeap.count,
                deadlineHeap[rightChild].deadline < deadlineHeap[leftChild].deadline
            {
                smallest = rightChild
            }

            guard deadlineHeap[smallest].deadline < deadlineHeap[parent].deadline else {
                return
            }

            deadlineHeap.swapAt(parent, smallest)
            heapIndices[deadlineHeap[parent].token] = parent
            heapIndices[deadlineHeap[smallest].token] = smallest
            parent = smallest
        }
    }

    private func sync<T>(_ action: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return action()
        }

        return queue.sync(execute: action)
    }
}
