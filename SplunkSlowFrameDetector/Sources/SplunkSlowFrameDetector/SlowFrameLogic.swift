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

    // MARK: - Types

    /// An error type specific to the `SlowFrameLogic` actor.
    enum LogicError: Error {
        /// Indicates that `start()` was called when the logic was already running.
        case alreadyRunning
    }


    // MARK: - Private Properties

    private var isRunning = false
    private var flushTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var destination: SlowFrameDetectorDestination?

    private var slowFrameCount: Int = 0
    private var frozenFrameCount: Int = 0

    private var lastFrameTimestamp: TimeInterval?
    private var lastHeartbeatTimestamp: TimeInterval = 0


    // MARK: - Test-only Properties

    #if DEBUG
        /// A test-only accessor for the current frozenFrameCount.
        var testFrozenFrameCount: Int { frozenFrameCount }
    #endif


    // MARK: - Initialization

    /// Initializes the logic actor with a destination for reporting frame data.
    /// - Parameter destination: The destination for reporting frame data.
    init(destination: SlowFrameDetectorDestination) {
        self.destination = destination
    }

    deinit {
        // Ensure background tasks are cancelled when the actor is deallocated
        watchdogTask?.cancel()
        flushTask?.cancel()
    }


    // MARK: - Public Methods

    /// Starts the background tasks for the watchdog and flush loop.
    ///
    /// - Throws: `LogicError.alreadyRunning` if the logic is already running.
    func start() throws {
        guard !isRunning else {
            throw LogicError.alreadyRunning
        }

        isRunning = true
        // Use a regular Task, as there's no need for it to be detached from the actor's context
        watchdogTask = Task { [weak self] in await self?.runWatchdog() }
        flushTask = Task { [weak self] in await self?.runFlushLoop() }
    }

    /// Stops the background tasks and flushes any remaining data.
    func stop() async {
        guard isRunning else {
            return
        }

        isRunning = false
        watchdogTask?.cancel()
        flushTask?.cancel()
        watchdogTask = nil
        flushTask = nil
        await flushBuffers()
        destination = nil
    }

    /// Handles an incoming frame update from the ticker.
    /// - Parameters:
    ///   - timestamp: The timestamp of the frame.
    ///   - duration: The expected duration of the frame.
    func handleFrame(timestamp: TimeInterval, duration: TimeInterval) {
        lastHeartbeatTimestamp = CACurrentMediaTime()

        guard let previousTimestamp = lastFrameTimestamp, duration > 0 else {
            lastFrameTimestamp = timestamp
            return
        }

        let deltaTime = timestamp - previousTimestamp
        let tolerance = duration * (SlowFrameDetector.slowFrameTolerancePercentage / 100.0)

        if deltaTime >= duration + tolerance {
            slowFrameCount += 1
        }

        lastFrameTimestamp = timestamp
    }


    // MARK: - Lifecycle Handlers

    func appWillResignActive() async {
        await flushBuffers()
    }

    func appDidBecomeActive() {
        lastFrameTimestamp = nil
        lastHeartbeatTimestamp = 0
        slowFrameCount = 0
        frozenFrameCount = 0
    }

    func appWillTerminate() async {
        await flushBuffers()
    }


    // MARK: - Internal Methods

    /// Flushes the collected slow and frozen frame counts to the destination.
    func flushBuffers() async {
        guard let destination else {
            return
        }

        // Drain slow frames
        if slowFrameCount > 0 {
            let count = slowFrameCount
            slowFrameCount = 0
            await destination.send(type: "slowRenders", count: count, sharedState: nil)
        }

        // Drain frozen frames
        if frozenFrameCount > 0 {
            let count = frozenFrameCount
            frozenFrameCount = 0
            await destination.send(type: "frozenRenders", count: count, sharedState: nil)
        }
    }


    // MARK: - Private Methods

    /// Periodically checks if the main thread has been unresponsive (frozen).
    ///
    /// This loop runs continuously in the background, sleeping for the duration of the
    /// frozen frame threshold. If the `lastHeartbeatTimestamp` (updated by `handleFrame`)
    /// has not changed within that time, it indicates a frozen frame.
    private func runWatchdog() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(SlowFrameDetector.frozenFrameThreshold * 1_000_000_000))
            if Task.isCancelled {
                break
            }
            let now = CACurrentMediaTime()
            if lastHeartbeatTimestamp > 0, (now - lastHeartbeatTimestamp) >= SlowFrameDetector.frozenFrameThreshold {
                frozenFrameCount += 1
            }
        }
    }

    /// Periodically flushes the collected frame data to the destination.
    ///
    /// This loop runs continuously in the background, triggering a flush of the
    /// slow and frozen frame buffers every second.
    private func runFlushLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled {
                break
            }
            await flushBuffers()
        }
    }
}
