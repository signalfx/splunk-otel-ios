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
    /// Drains a snapshot to the exporter without waiting for background URLSession activity.
    ///
    /// The configured exporter reports success only after the batch has been written to disk. This
    /// operation is therefore suitable for protecting a source payload that must not be deleted
    /// until the span has a durable copy.
    func persistBufferedSpans(timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        let boundedTimeout = timeout.isFinite ? max(0, timeout) : 0
        let deadline = Date().addingTimeInterval(boundedTimeout)

        processorQueue.async {
            let succeeded = self.drainSnapshot(
                deadline: deadline,
                requeueOnFailure: true,
                forwardDeadlineToExporter: false
            )
            completion(succeeded)
        }
    }
}
