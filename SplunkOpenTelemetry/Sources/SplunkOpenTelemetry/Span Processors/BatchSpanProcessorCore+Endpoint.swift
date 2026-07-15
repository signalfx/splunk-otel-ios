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

/// Endpoint-transition work for ``BatchSpanProcessorCore``.
extension BatchSpanProcessorCore {

    /// Drains the spans present when this work reaches `processorQueue`, then applies the endpoint mutation.
    ///
    /// An empty buffer skips exporter flushing entirely.
    func transitionEndpoint(
        timeout: TimeInterval?,
        applyEndpoint: @escaping () -> Void
    ) -> Bool {
        let waitTimeout = forceFlushWaitTimeout(for: timeout)
        let deadline = Date().addingTimeInterval(waitTimeout)

        if DispatchQueue.getSpecific(key: processorQueueKey) != nil {
            return performEndpointTransition(deadline: deadline, applyEndpoint: applyEndpoint)
        }

        let completed = DispatchSemaphore(value: 0)
        let resultLock = NSLock()
        var transitionSucceeded = false

        processorQueue.async {
            let result = self.performEndpointTransition(deadline: deadline, applyEndpoint: applyEndpoint)
            resultLock.lock()
            transitionSucceeded = result
            resultLock.unlock()
            completed.signal()
        }

        guard completed.wait(timeout: .now() + waitTimeout) == .success else {
            return false
        }

        resultLock.lock()
        defer { resultLock.unlock() }
        return transitionSucceeded
    }

    private func performEndpointTransition(deadline: Date, applyEndpoint: () -> Void) -> Bool {
        lock.lock()
        let hasBufferedSpans = !queue.isEmpty
        lock.unlock()

        if hasBufferedSpans {
            guard
                drainSnapshot(
                    deadline: deadline,
                    requeueOnFailure: true,
                    forwardDeadlineToExporter: false
                )
            else {
                return false
            }

            guard Date() < deadline else {
                return false
            }

            let flushResult = spanExporter.flush(explicitTimeout: max(0, deadline.timeIntervalSinceNow))
            guard flushResult != .failure else {
                return false
            }
        }

        guard Date() < deadline else {
            return false
        }

        applyEndpoint()
        return true
    }
}
