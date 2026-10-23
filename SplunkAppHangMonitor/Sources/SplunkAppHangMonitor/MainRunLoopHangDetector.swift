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
    private let spanRecorder = AppHangSpanRecorder()

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
            for observer in lifecycleObservers {
                NotificationCenter.default.removeObserver(observer)
            }
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

            spanRecorder.configure(
                thresholdMilliseconds: thresholdMilliseconds,
                interactionAssociationEnabled: interactionAssociationEnabled,
                interactionAssociationWindowMilliseconds: interactionAssociationWindowMilliseconds
            )
        }
    }


    // MARK: - Lifecycle

    func start() {
        performOnMain { [weak self] in
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
        performOnMain { [weak self] in
            guard let self else {
                return
            }

            hasStarted = false
            manuallyPaused = false
            endObserving(interrupted: true)
            for observer in lifecycleObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            lifecycleObservers.removeAll()
        }
    }

    func pause() {
        performOnMain { [weak self] in
            guard let self else {
                return
            }

            manuallyPaused = true
            endObserving(interrupted: true)
        }
    }

    func resume() {
        performOnMain { [weak self] in
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
            guard let self else {
                return
            }

            spanRecorder.recordInteraction(at: estimatedOccurrence, type: type)
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

        let activities =
            CFRunLoopActivity.afterWaiting.rawValue
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
            spanRecorder.updateClockOffset(at: CACurrentMediaTime())
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
            timer.schedule(deadline: .distantFuture)
        }
    }

    private func setPaused(_ value: Bool) {
        statusLock.lock()
        storedIsPaused = value
        statusLock.unlock()
    }

    // MARK: - Detection

    private func handleRunLoopActivity(_ activity: CFRunLoopActivity, at timestamp: TimeInterval) {
        guard isActive else {
            return
        }

        if activity == .afterWaiting {
            busyStart = timestamp
        }
        else if activity == .beforeWaiting || activity == .exit {
            finishBusyInterval(at: timestamp, complete: true)
        }
    }

    private func checkThreshold() {
        guard
            isActive,
            !spanRecorder.hasActiveSpan,
            let busyStart,
            CACurrentMediaTime() - busyStart > spanRecorder.threshold
        else {
            return
        }

        spanRecorder.openSpan(startingAt: busyStart)
    }

    private func finishBusyInterval(at endTime: TimeInterval, complete: Bool) {
        guard let busyStart else {
            return
        }

        if !spanRecorder.hasActiveSpan, endTime - busyStart > spanRecorder.threshold {
            spanRecorder.openSpan(startingAt: busyStart)
        }

        spanRecorder.finish(at: endTime, complete: complete)

        self.busyStart = nil
    }
}

private func performOnMain(_ action: @escaping () -> Void) {
    if Thread.isMainThread {
        action()
    }
    else {
        DispatchQueue.main.async(execute: action)
    }
}
