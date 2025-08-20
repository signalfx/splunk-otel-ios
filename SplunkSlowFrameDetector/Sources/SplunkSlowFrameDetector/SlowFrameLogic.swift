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

// MARK: - SlowFrameLogic Actor

/// An actor that encapsulates the core state and logic for the `SlowFrameDetector`.
///
/// It isolates the complex, concurrent operations of frame analysis and reporting from the main class, which serves as a simple public API facade. The name "Logic" reflects its role in containing the business logic of the feature.
internal actor SlowFrameLogic {

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

    init(destinationFactory: @escaping () -> SlowFrameDetectorDestination) {
        self.destinationFactory = destinationFactory
    }

    func start() -> Bool {
        guard !isRunning else { return false }
        isRunning = true
        destination = destinationFactory()
        watchdogTask = Task.detached(priority: .background) { [weak self] in await self?.runWatchdog() }
        flushTask = Task { [weak self] in await self?.runFlushLoop() }
        return true
    }

    func stop() async {
        guard isRunning else { return }
        isRunning = false
        watchdogTask?.cancel()
        flushTask?.cancel()
        destination = nil
        await flushBuffers()
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

    private func runWatchdog() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(SlowFrameDetector.frozenFrameThreshold * 1_000_000_000))
            if Task.isCancelled { break }
            let now = CACurrentMediaTime()
            if lastHeartbeatTimestamp > 0 && (now - lastHeartbeatTimestamp) >= SlowFrameDetector.frozenFrameThreshold {
                await frozenFrames.increment()
            }
        }
    }

    private func runFlushLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { break }
            await flushBuffers()
        }
    }

    func flushBuffers() async {
        guard let destination else { return }
        for (type, buffer) in [("slowRenders",   slowFrames), ("frozenRenders", frozenFrames)] {
            let counts = await buffer.drain()
            guard let count = counts["shared"], count > 0 else { continue }
            await destination.send(type: type, count: count, sharedState: nil)
        }
    }
}

