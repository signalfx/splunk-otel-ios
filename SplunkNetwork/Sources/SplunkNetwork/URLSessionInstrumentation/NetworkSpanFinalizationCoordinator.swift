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

/// Coordinates the competing URL session completion paths for one network span.
///
/// Both the task-state swizzle and a wrapped completion handler can observe completion. This
/// coordinator ensures that exactly one of them enriches and ends the span. The task is retained
/// weakly because it retains this coordinator through an associated object.
///
/// Safety: all mutable state is protected by `lock`. Finalization is claimed under the lock, but
/// attribute writes and `Span.end()` run after unlocking so callbacks into the telemetry pipeline
/// cannot deadlock or re-enter the coordinator while it is locked.
final class NetworkSpanFinalizationCoordinator: @unchecked Sendable {

    // MARK: - Private properties

    private let lock = NSLock()
    private weak var task: URLSessionTask?
    private var pendingCompletion: (response: URLResponse?, error: Error?)?
    private var isFinalized = false


    // MARK: - Properties

    let span: Span


    // MARK: - Initialization

    init(span: Span) {
        self.span = span
    }


    // MARK: - Coordination

    /// Attaches the task after URLSession has returned it from its creation method.
    func attach(to task: URLSessionTask) {
        let pending: (response: URLResponse?, error: Error?)?

        lock.lock()
        self.task = task
        if !isFinalized, let storedCompletion = pendingCompletion {
            isFinalized = true
            pendingCompletion = nil
            pending = storedCompletion
        }
        else {
            pending = nil
        }
        lock.unlock()

        if let pending {
            endHttpSpan(
                span: span,
                task: task,
                fallbackResponse: pending.response,
                fallbackError: pending.error
            )
        }
    }

    /// Finalizes from the task-state callback, using the completed task as the canonical data source.
    func finalize(task: URLSessionTask) {
        lock.lock()
        guard !isFinalized else {
            lock.unlock()
            return
        }

        isFinalized = true
        pendingCompletion = nil
        lock.unlock()

        endHttpSpan(span: span, task: task)
    }

    /// Finalizes from a completion handler while retaining task-derived enrichment when available.
    func finalize(response: URLResponse?, error: Error?) {
        let attachedTask: URLSessionTask

        lock.lock()
        guard !isFinalized else {
            lock.unlock()
            return
        }

        guard let task else {
            // A URLSession task normally cannot complete before it has been returned and attached.
            // Store the completion defensively so attachment can perform canonical finalization.
            if pendingCompletion == nil {
                pendingCompletion = (response, error)
            }
            lock.unlock()
            return
        }

        isFinalized = true
        pendingCompletion = nil
        attachedTask = task
        lock.unlock()

        endHttpSpan(
            span: span,
            task: attachedTask,
            fallbackResponse: response,
            fallbackError: error
        )
    }
}
