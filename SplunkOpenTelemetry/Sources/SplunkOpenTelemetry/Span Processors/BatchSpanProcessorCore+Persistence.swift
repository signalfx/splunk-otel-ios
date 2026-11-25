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
import OpenTelemetryApi

extension BatchSpanProcessorCore {
    /// Drains a snapshot to the exporter without waiting for background URLSession activity.
    ///
    /// The configured exporter reports success after it writes the batch to disk. In an agent's
    /// pipeline, success also covers a span that the session policy dropped, which has no durable
    /// copy. For a caller that keeps a source payload until success, success means that the span was
    /// stored, or dropped on purpose by the session policy, the interceptor check or the app's span
    /// interceptor returning `nil`.
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

    /// Emits a span on the processor queue and persists a snapshot containing that exact span.
    ///
    /// Success means that the span was stored, or dropped on purpose by the session policy, the
    /// interceptor check or the app's span interceptor returning `nil`.
    func persistSpan(
        emitting emitSpan: @escaping () -> SpanId,
        timeout: TimeInterval,
        completion: @escaping (Bool) -> Void
    ) {
        let boundedTimeout = timeout.isFinite ? max(0, timeout) : 0
        let deadline = Date().addingTimeInterval(boundedTimeout)

        processorQueue.async {
            let spanId = emitSpan()

            self.lock.lock()
            let wasAdmitted = self.queue.contains(spanId: spanId)
            self.lock.unlock()

            guard wasAdmitted else {
                completion(false)
                return
            }

            let succeeded = self.drainSnapshot(
                deadline: deadline,
                requeueOnFailure: true,
                forwardDeadlineToExporter: false
            )
            completion(succeeded)
        }
    }
}
