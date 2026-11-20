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
@_spi(SplunkInternal) import SplunkCommon

/// Coordinates the competing URL session completion paths for one network span.
///
/// Both the task-state swizzle and a wrapped completion handler can observe completion. This
/// coordinator ensures that exactly one of them enriches and ends the span. The task is retained
/// weakly because it retains this coordinator through an associated object.
///
/// Safety: all mutable state is protected by `lock`. Finalization is claimed under the lock, but
/// most attribute writes and `Span.end()` run after unlocking so callbacks into the telemetry
/// pipeline cannot deadlock or re-enter the coordinator while it is locked. The request-started
/// event is recorded while the lock is held so the event and started-state transition are atomic
/// with respect to terminal callbacks.
final class NetworkSpanFinalizationCoordinator: @unchecked Sendable {

    // MARK: - Constants

    /// The maximum time an ordinary data or upload request may remain open in telemetry.
    static let defaultWatchdogDelay: TimeInterval = 5 * 60

    /// Downloads and uploads can legitimately outlive an ordinary request, so they receive a longer limit.
    static let longLivedWatchdogDelay: TimeInterval = 30 * 60

    static let timeoutErrorType = "instrumentation.timeout"
    static let timeoutErrorMessage = "Network task did not provide a completion callback before the SDK deadline"

    // MARK: - Private properties

    private let lock = NSLock()
    private weak var task: URLSessionTask?
    private var pendingFinalization: PendingFinalization?
    private var isFinalized = false
    private var hasStarted = false
    private var watchdogToken: NetworkSpanWatchdogScheduler.Token?


    // MARK: - Properties

    let span: Span


    // MARK: - Private types

    private struct PendingFinalization {
        let response: URLResponse?
        let error: Error?
    }


    // MARK: - Initialization

    init(
        span: Span,
        watchdogDelay: TimeInterval? = nil,
        watchdogScheduler: NetworkSpanWatchdogScheduler? = nil
    ) {
        self.span = span
        self.watchdogDelay = watchdogDelay
        self.watchdogScheduler = watchdogScheduler ?? NetworkInstrumentationManager.shared.watchdogScheduler
    }

    private let watchdogDelay: TimeInterval?
    private let watchdogScheduler: NetworkSpanWatchdogScheduler


    // MARK: - Coordination

    /// Attaches the task after URLSession has returned it from its creation method.
    func attach(to task: URLSessionTask) {
        let pending: PendingFinalization?
        let watchdogToken: NetworkSpanWatchdogScheduler.Token?

        lock.lock()
        self.task = task
        if hasStarted, !isFinalized, let storedFinalization = pendingFinalization {
            isFinalized = true
            pendingFinalization = nil
            watchdogToken = self.watchdogToken
            self.watchdogToken = nil
            pending = storedFinalization
        }
        else {
            watchdogToken = nil
            pending = nil
        }
        lock.unlock()

        if let watchdogToken {
            watchdogScheduler.cancel(watchdogToken)
        }

        if let pending {
            endHttpSpan(
                span: span,
                task: task,
                fallbackResponse: pending.response,
                fallbackError: pending.error
            )
        }
    }

    /// Records the moment the task was resumed and starts the independent telemetry watchdog.
    ///
    /// The span itself is created earlier so its context can be injected into the request. A
    /// request-started event is recorded here and the exporter later uses that event timestamp as
    /// the span start time.
    func start(task: URLSessionTask, at startTime: Date = Date()) {
        let pending: PendingFinalization?
        let delay = watchdogDelay ?? Self.watchdogDelay(for: task)

        lock.lock()
        guard !isFinalized, !hasStarted else {
            lock.unlock()
            return
        }

        hasStarted = true
        span.addEvent(name: NetworkInstrumentationConstants.requestStartedEventName, timestamp: startTime)

        if let storedFinalization = pendingFinalization {
            isFinalized = true
            pendingFinalization = nil
            pending = storedFinalization
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
        else {
            let token = watchdogScheduler.schedule(after: max(0, delay)) { [weak self] in
                guard let self else {
                    return
                }

                finalizeTimeout(at: startTime.addingTimeInterval(max(0, delay)))
            }

            lock.lock()
            if isFinalized {
                lock.unlock()
                watchdogScheduler.cancel(token)
            }
            else {
                watchdogToken = token
                lock.unlock()
            }
        }
    }

    /// Finalizes from the task-state callback, using the completed task as the canonical data source.
    func finalize(task: URLSessionTask) {
        let watchdogToken: NetworkSpanWatchdogScheduler.Token?
        let storedFinalization: PendingFinalization?

        lock.lock()
        guard !isFinalized else {
            lock.unlock()
            return
        }

        storedFinalization = pendingFinalization
        if !hasStarted {
            let completionErrors = [task.error, storedFinalization?.error].compactMap(\.self)
            let hasNonCancellationError = completionErrors.contains { !Self.isCancellationError($0) }
            let hasTerminalEvidence =
                task.response != nil
                || task.countOfBytesSent > 0
                || task.countOfBytesReceived > 0
                || hasNonCancellationError
            guard hasTerminalEvidence else {
                pendingFinalization = PendingFinalization(response: nil, error: nil)
                lock.unlock()
                return
            }
        }

        isFinalized = true
        pendingFinalization = nil
        watchdogToken = self.watchdogToken
        self.watchdogToken = nil
        lock.unlock()

        if let watchdogToken {
            watchdogScheduler.cancel(watchdogToken)
        }

        endHttpSpan(
            span: span,
            task: task,
            fallbackResponse: storedFinalization?.response,
            fallbackError: storedFinalization?.error
        )
    }

    /// Finalizes from a completion handler while retaining task-derived enrichment when available.
    func finalize(response: URLResponse?, error: Error?) {
        let attachedTask: URLSessionTask
        let watchdogToken: NetworkSpanWatchdogScheduler.Token?

        lock.lock()
        guard !isFinalized else {
            lock.unlock()
            return
        }

        guard hasStarted else {
            // A completion callback without a resume() call is not a network request. Keep the
            // callback only in case resume and completion race while the task is being attached.
            pendingFinalization = PendingFinalization(response: response, error: error)
            lock.unlock()
            return
        }

        guard let task else {
            // The completion handler can race task attachment. Keep the callback until the task
            // is attached so response attributes can still be collected before ending the span.
            pendingFinalization = PendingFinalization(response: response, error: error)
            lock.unlock()
            return
        }

        isFinalized = true
        pendingFinalization = nil
        watchdogToken = self.watchdogToken
        self.watchdogToken = nil
        attachedTask = task
        lock.unlock()

        if let watchdogToken {
            watchdogScheduler.cancel(watchdogToken)
        }

        endHttpSpan(
            span: span,
            task: attachedTask,
            fallbackResponse: response,
            fallbackError: error
        )
    }

    /// Finalizes a started span when URLSession fails to deliver any terminal callback.
    ///
    /// This path deliberately does not read the live task. URLSession may still be updating the
    /// task while the watchdog runs, so timeout telemetry is limited to attributes already on the
    /// span and ends at the configured watchdog deadline.
    func finalizeTimeout(at endTime: Date) {
        let watchdogToken: NetworkSpanWatchdogScheduler.Token?

        lock.lock()
        guard hasStarted, !isFinalized else {
            lock.unlock()
            return
        }

        isFinalized = true
        pendingFinalization = nil
        watchdogToken = self.watchdogToken
        self.watchdogToken = nil
        lock.unlock()

        if let watchdogToken {
            watchdogScheduler.cancel(watchdogToken)
        }

        endHttpSpan(
            span: span,
            errorTypeOverride: Self.timeoutErrorType,
            errorMessageOverride: Self.timeoutErrorMessage,
            endTime: endTime
        )
    }

    static func watchdogDelay(for task: URLSessionTask) -> TimeInterval {
        task is URLSessionDownloadTask || task is URLSessionUploadTask
            ? longLivedWatchdogDelay
            : defaultWatchdogDelay
    }

    private static func isCancellationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
