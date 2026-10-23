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
import QuartzCore
@_spi(SplunkInternal) import SplunkCommon

#if canImport(UIKit)
    import UIKit
#endif

/// Observes main-run-loop busy intervals and checks them from one serial off-main queue.
final class MainRunLoopHangDetector {

    // MARK: - Private Properties

    private let workerQueue = DispatchQueue(label: PackageIdentifier.default(named: "AppHangMonitor"))
    private let timer: DispatchSourceTimer
    private let statusLock = NSLock()

    // Main-thread-owned lifecycle state.
    private var hasStarted = false
    private var manuallyPaused = false
    private var runLoopObserver: CFRunLoopObserver?
    private var lifecycleObservers: [NSObjectProtocol] = []

    // State below is only accessed on workerQueue.
    private var isActive = false
    private var busyStart: TimeInterval?
    private var busyStartDate: Date?
    private var lastInteractionTime: TimeInterval?
    private var lastInteractionType: String?
    private var wallClockOffset: TimeInterval = 0
    private var activeSpan: (span: any Span, start: TimeInterval)?
    private var threshold: TimeInterval = 0.25
    private var interactionAssociationEnabled = true
    private var interactionAssociationWindow: TimeInterval = 5

    private var storedIsPaused = true


    // MARK: - Initialization

    init() {
        timer = DispatchSource.makeTimerSource(queue: workerQueue)
        timer.schedule(deadline: .distantFuture)
        timer.setEventHandler { [weak self] in
            self?.checkThreshold()
        }
        timer.resume()
    }

    deinit {
        timer.cancel()
        DispatchQueue.main.async { [runLoopObserver, lifecycleObservers] in
            if let runLoopObserver {
                CFRunLoopObserverInvalidate(runLoopObserver)
            }
            lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        }
    }


    // MARK: - Public State

    var isPaused: Bool {
        statusLock.lock()
        defer { statusLock.unlock() }
        return storedIsPaused
    }


    // MARK: - Configuration

    func configure(
        thresholdMilliseconds: Int,
        interactionAssociationEnabled: Bool,
        interactionAssociationWindowMilliseconds: Int
    ) {
        workerQueue.async { [weak self] in
            guard let self else {
                return
            }

            threshold = TimeInterval(thresholdMilliseconds) / 1_000
            self.interactionAssociationEnabled = interactionAssociationEnabled
            interactionAssociationWindow = TimeInterval(interactionAssociationWindowMilliseconds) / 1_000
        }
    }


    // MARK: - Lifecycle

    func start() {
        onMain { [weak self] in
            guard let self, !hasStarted else {
                return
            }

            hasStarted = true
            registerLifecycleObservers()

            #if canImport(UIKit)
                if UIApplication.shared.applicationState == .active, !manuallyPaused {
                    beginObserving()
                }
            #else
                if !manuallyPaused {
                    beginObserving()
                }
            #endif
        }
    }

    func stop() {
        onMain { [weak self] in
            guard let self else {
                return
            }

            hasStarted = false
            manuallyPaused = false
            endObserving(interrupted: true)
            lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
            lifecycleObservers.removeAll()
        }
    }

    func pause() {
        onMain { [weak self] in
            guard let self else {
                return
            }

            manuallyPaused = true
            endObserving(interrupted: true)
        }
    }

    func resume() {
        onMain { [weak self] in
            guard let self, hasStarted else {
                return
            }

            manuallyPaused = false
            #if canImport(UIKit)
                if UIApplication.shared.applicationState == .active {
                    beginObserving()
                }
            #else
                beginObserving()
            #endif
        }
    }

    func recordInteraction(at timestamp: Date, type: String) {
        let receivedAt = CACurrentMediaTime()
        let age = max(0, Date().timeIntervalSince(timestamp))
        let estimatedOccurrence = receivedAt - age

        workerQueue.async { [weak self] in
            guard let self, interactionAssociationEnabled else {
                return
            }

            if let lastInteractionTime, estimatedOccurrence < lastInteractionTime {
                return
            }

            lastInteractionTime = estimatedOccurrence
            lastInteractionType = type
        }
    }


    // MARK: - Main Run Loop

    private func registerLifecycleObservers() {
        #if canImport(UIKit)
            let center = NotificationCenter.default
            lifecycleObservers = [
                center.addObserver(
                    forName: UIApplication.willResignActiveNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.endObserving(interrupted: true)
                },
                center.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    guard let self, hasStarted, !manuallyPaused else {
                        return
                    }

                    beginObserving()
                }
            ]
        #endif
    }

    private func beginObserving() {
        guard runLoopObserver == nil else {
            return
        }

        let activities = CFRunLoopActivity.afterWaiting.rawValue
            | CFRunLoopActivity.beforeWaiting.rawValue
            | CFRunLoopActivity.exit.rawValue
        let observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            activities,
            true,
            0,
            { [weak self] _, activity in
            guard let self else {
                return
            }

            let monotonicTime = CACurrentMediaTime()
            workerQueue.async {
                self.handleRunLoopActivity(activity, at: monotonicTime)
            }
            }
        )
        guard let observer else {
            setPaused(true)
            return
        }

        runLoopObserver = observer
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        setPaused(false)

        workerQueue.async { [weak self] in
            guard let self else {
                return
            }

            isActive = true
            busyStart = nil
            busyStartDate = nil
            wallClockOffset = Date().timeIntervalSince1970 - CACurrentMediaTime()
            timer.schedule(
                deadline: .now() + AppHangMonitorConstants.watchdogInterval,
                repeating: AppHangMonitorConstants.watchdogInterval,
                leeway: .milliseconds(5)
            )
        }
    }

    private func endObserving(interrupted: Bool) {
        if let observer = runLoopObserver {
            CFRunLoopObserverInvalidate(observer)
            runLoopObserver = nil
        }

        setPaused(true)
        let monotonicTime = CACurrentMediaTime()
        workerQueue.async { [weak self] in
            guard let self else {
                return
            }

            if interrupted {
                finishBusyInterval(at: monotonicTime, complete: false)
            }

            isActive = false
            busyStart = nil
            busyStartDate = nil
            timer.schedule(deadline: .distantFuture)
        }
    }

    private func setPaused(_ value: Bool) {
        statusLock.lock()
        storedIsPaused = value
        statusLock.unlock()
    }

    private func onMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        }
        else {
            DispatchQueue.main.async(execute: action)
        }
    }


    // MARK: - Detection

    private func handleRunLoopActivity(_ activity: CFRunLoopActivity, at timestamp: TimeInterval) {
        guard isActive else {
            return
        }

        if activity == .afterWaiting {
            busyStart = timestamp
            busyStartDate = Date(timeIntervalSince1970: timestamp + wallClockOffset)
        }
        else if activity == .beforeWaiting || activity == .exit {
            finishBusyInterval(at: timestamp, complete: true)
        }
    }

    private func checkThreshold() {
        guard isActive, activeSpan == nil, let busyStart, CACurrentMediaTime() - busyStart > threshold else {
            return
        }

        openSpan(startingAt: busyStart, detectedAt: CACurrentMediaTime())
    }

    private func finishBusyInterval(at endTime: TimeInterval, complete: Bool) {
        guard let busyStart else {
            return
        }

        if activeSpan == nil, endTime - busyStart > threshold {
            openSpan(startingAt: busyStart, detectedAt: endTime)
        }

        if let activeSpan {
            activeSpan.span.clearAndSetAttribute(
                key: AppHangMonitorConstants.durationMilliseconds,
                value: max(0, endTime - activeSpan.start) * 1_000
            )
            activeSpan.span.clearAndSetAttribute(
                key: AppHangMonitorConstants.durationIsComplete,
                value: complete
            )
            activeSpan.span.clearAndSetAttribute(
                key: AppHangMonitorConstants.outcome,
                value: complete ? "recovered" : "interrupted"
            )
            activeSpan.span.end(time: date(for: endTime))
            self.activeSpan = nil
        }

        self.busyStart = nil
        busyStartDate = nil
    }

    private func openSpan(startingAt startTime: TimeInterval, detectedAt: TimeInterval) {
        guard let busyStartDate else {
            return
        }

        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(instrumentationName: AppHangMonitorConstants.instrumentationName)

        let span = tracer.spanBuilder(spanName: AppHangMonitorConstants.spanName)
            .setStartTime(time: busyStartDate)
            .startSpan()

        span.clearAndSetAttribute(key: "component", value: AppHangMonitorConstants.component)
        span.clearAndSetAttribute(key: AppHangMonitorConstants.thresholdMilliseconds, value: threshold * 1_000)

        if interactionAssociationEnabled,
           let lastInteractionTime,
           detectedAt - lastInteractionTime <= interactionAssociationWindow,
           detectedAt >= lastInteractionTime
        {
            span.clearAndSetAttribute(key: AppHangMonitorConstants.interactionEvidence, value: "recent_observed")
            if let lastInteractionType {
                span.clearAndSetAttribute(key: AppHangMonitorConstants.interactionType, value: lastInteractionType)
            }
            span.clearAndSetAttribute(
                key: AppHangMonitorConstants.interactionAgeMilliseconds,
                value: (detectedAt - lastInteractionTime) * 1_000
            )
        }

        activeSpan = (span, startTime)
    }

    private func date(for monotonicTime: TimeInterval) -> Date {
        Date(timeIntervalSince1970: monotonicTime + wallClockOffset)
    }
}
