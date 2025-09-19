//
/*
Copyright 2025 Splunk Inc.

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

/// An actor that encapsulates the core state and logic for the `SlowFrameDetector`.
///
/// It isolates the complex, concurrent operations and logic of frame analysis and reporting
/// from the main class, which serves as a simple public API facade.
actor SlowFrameLogic {

    enum LogicError: Error {
        case alreadyRunning
    }

    typealias FrameBuffer = [String: Int]
    actor ReportableFramesBuffer {
        private var buffer: FrameBuffer = [:]
        func increment() { buffer["shared", default: 0] += 1 }
        func drain() -> FrameBuffer {
            defer { buffer.removeAll() }
            return buffer
        }
    }

    private var isRunning = false
    private var flushTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var destinationFactory: () -> SlowFrameDetectorDestination
    private var destination: SlowFrameDetectorDestination?
    private let slowFrames = ReportableFramesBuffer()
    private let frozenFrames = ReportableFramesBuffer()
    private var lastFrameTimestamp: TimeInterval?
    private var lastHeartbeatTimestamp: TimeInterval = 0

    #if DEBUG
    // A test-only hook called after a flush completes
    var onFlushDidComplete: (() -> Void)?

    // A test-only method to set the flush completion handler
    func setOnFlushDidComplete(_ handler: (() -> Void)?) {
        self.onFlushDidComplete = handler
    }
    #endif

    init(destinationFactory: @escaping () -> SlowFrameDetectorDestination) {
        self.destinationFactory = destinationFactory
    }

    deinit {
        // Ensure background tasks are cancelled when the actor is deallocated.
        watchdogTask?.cancel()
        flushTask?.cancel()
    }

    func start() throws {
        guard !isRunning else { throw LogicError.alreadyRunning }
        isRunning = true
        destination = destinationFactory()
        // Use a regular Task, as there's no need for it to be detached from the actor's context.
        watchdogTask = Task { [weak self] in await self?.runWatchdog() }
        flushTask = Task { [weak self] in await self?.runFlushLoop() }
    }

    func stop() async {
        guard isRunning else { return }
        isRunning = false
        watchdogTask?.cancel()
        flushTask?.cancel()
        watchdogTask = nil
        flushTask = nil
        await flushBuffers()
        destination = nil
    }

    func appWillResignActive() async { await flushBuffers() }
    func appDidBecomeActive() { lastFrameTimestamp = nil; lastHeartbeatTimestamp = 0 }
    func appWillTerminate() async { await flushBuffers() }

    func handleFrame(timestamp: TimeInterval, duration: TimeInterval) {
        lastHeartbeatTimestamp = CACurrentMediaTime()

        guard let previousTimestamp = lastFrameTimestamp, duration > 0 else {
            lastFrameTimestamp = timestamp
            return
        }

        let deltaTime = timestamp - previousTimestamp
        let tolerance = duration * (SlowFrameDetector.slowFrameTolerancePercentage / 100.0)

        if deltaTime >= duration + tolerance {
            Task { await slowFrames.increment() }
        }

        lastFrameTimestamp = timestamp
    }

    /// Periodically checks if the main thread has been unresponsive (frozen).
    private func runWatchdog() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(SlowFrameDetector.frozenFrameThreshold * 1_000_000_000))
            if Task.isCancelled { break }
            let now = CACurrentMediaTime()
            if lastHeartbeatTimestamp > 0, (now - lastHeartbeatTimestamp) >= SlowFrameDetector.frozenFrameThreshold {
                await frozenFrames.increment()
            }
        }
    }

    /// Periodically flushes the collected frame data to the destination.
    private func runFlushLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { break }
            await flushBuffers()
        }
    }

    internal func flushBuffers() async {
        guard let destination else { return }
        for (type, buffer) in [("slowRenders", slowFrames), ("frozenRenders", frozenFrames)] {
            let counts = await buffer.drain()
            guard let count = counts["shared"], count > 0 else { continue }
            await destination.send(type: type, count: count, sharedState: nil)
        }

        #if DEBUG
        onFlushDidComplete?()
        #endif
    }
}
