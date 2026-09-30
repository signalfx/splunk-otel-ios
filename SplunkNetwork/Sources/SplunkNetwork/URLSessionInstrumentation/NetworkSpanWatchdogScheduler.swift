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
final class NetworkSpanWatchdogScheduler: @unchecked Sendable {

    typealias Token = UUID

    // MARK: - Private types

    private struct Entry {
        let deadline: UInt64
        let action: () -> Void
    }

    // MARK: - Private properties

    private let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Void>()
    private let timer: DispatchSourceTimer
    private var entries: [Token: Entry] = [:]

    // MARK: - Initialization

    init(
        queue: DispatchQueue = DispatchQueue(
            label: PackageIdentifier.default(named: "NetworkSpanWatchdog"),
            qos: .utility
        ),
        tickInterval: TimeInterval = 1
    ) {
        self.queue = queue
        queue.setSpecific(key: queueKey, value: ())

        timer = DispatchSource.makeTimerSource(queue: queue)
        let interval = max(0.01, tickInterval)
        timer.setEventHandler { [weak self] in
            self?.expireEntries()
        }
        timer.schedule(deadline: .now() + interval, repeating: interval)
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
        let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
        let deadline = DispatchTime.now().uptimeNanoseconds + nanoseconds

        sync {
            entries[token] = Entry(deadline: deadline, action: action)
        }

        return token
    }

    func cancel(_ token: Token) {
        sync {
            entries.removeValue(forKey: token)
        }
    }

    // MARK: - Private methods

    private func expireEntries() {
        let now = DispatchTime.now().uptimeNanoseconds
        let expiredTokens = entries.compactMap { token, entry in
            entry.deadline <= now ? token : nil
        }
        let actions = expiredTokens.compactMap { entries.removeValue(forKey: $0)?.action }

        actions.forEach { $0() }
    }

    private func sync<T>(_ action: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return action()
        }

        return queue.sync(execute: action)
    }
}
