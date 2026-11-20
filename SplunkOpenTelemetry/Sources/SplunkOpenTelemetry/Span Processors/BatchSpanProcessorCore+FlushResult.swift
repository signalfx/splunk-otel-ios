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

extension BatchSpanProcessorCore {

    /// Flushes the current snapshot and returns an honest completion result.
    ///
    /// Main-thread callers are never blocked: their flush is scheduled asynchronously and success
    /// indicates that the best-effort work was accepted. Off-main success indicates completion.
    func forceFlushResult(timeout: TimeInterval?) -> Bool {
        let waitTimeout = forceFlushWaitTimeout(for: timeout)
        let deadline = Date().addingTimeInterval(waitTimeout)

        if DispatchQueue.getSpecific(key: processorQueueKey) != nil {
            return performForceFlush(deadline: deadline)
        }

        guard !Thread.isMainThread else {
            processorQueue.async {
                _ = self.performForceFlush(deadline: deadline)
            }
            return true
        }

        let completed = DispatchSemaphore(value: 0)
        let resultLock = NSLock()
        var flushSucceeded = false

        processorQueue.async {
            let result = self.performForceFlush(deadline: deadline)
            resultLock.lock()
            flushSucceeded = result
            resultLock.unlock()
            completed.signal()
        }

        guard completed.wait(timeout: .now() + waitTimeout) == .success else {
            return false
        }

        resultLock.lock()
        defer { resultLock.unlock() }
        return flushSucceeded
    }
}
