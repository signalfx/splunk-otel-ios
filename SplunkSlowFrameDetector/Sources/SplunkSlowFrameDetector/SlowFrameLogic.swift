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

    private var previousTargetTimestamp: TimeInterval?

    /// The presentation timestamp of the previous frame.
    ///
    /// Used to measure the inter-frame gap for the frozen-frame test, matching the timebase the
    /// background watchdog uses. Slow-frame detection instead uses `previousTargetTimestamp`.
    private var previousFrameTimestamp: TimeInterval?

    private var lastHeartbeatTimestamp: TimeInterval = 0

    /// Whether a continuous freeze episode is currently open.
    ///
    /// Ensures a single freeze is reported once, whether it is detected by the watchdog or by the
    /// lateness of the frame that ends it.
    private var inFreezeEpisode = false

    /// Whether the app is currently active (foregrounded).
    ///
    /// `handleFrame` is a no-op while this is `false`. This closes a race between the frame-consuming
    /// `AsyncStream` loop and the lifecycle-notification loop, which run as separate tasks and have no
    /// ordering guarantee against each other: without this guard, a frame still in flight when the app
    /// resigns active can re-arm `lastHeartbeatTimestamp` after `appWillResignActive` clears it, letting
    /// the watchdog count a spurious frozen frame while backgrounded.
    private var isActive = true

    /// A lower bound on acceptable frame timestamps after the app foregrounds.
    ///
    /// Set when the app becomes active and cleared once the first current frame is accepted. A
    /// `CADisplayLink` tick produced before backgrounding can sit buffered in the frame stream and be
    /// delivered to this actor only after `appDidBecomeActive` re-enables handling; `isActive` alone
    /// cannot reject it, since it reflects when the tick is processed rather than when it was produced.
    /// Without this cutoff the stale timestamp would seed the baseline, making the next real frame's gap
    /// span the whole background interval and emit a spurious frozen render.
    private var activationTimestamp: TimeInterval?


    // MARK: - Test-only Properties

    #if DEBUG
        /// A test-only accessor for the current slowFrameCount.
        var testSlowFrameCount: Int {
            slowFrameCount
        }

        /// A test-only accessor for the current frozenFrameCount.
        var testFrozenFrameCount: Int {
            frozenFrameCount
        }

        /// A test-only accessor for the current lastHeartbeatTimestamp.
        var testLastHeartbeatTimestamp: TimeInterval {
            lastHeartbeatTimestamp
        }
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
    func stop() {
        guard isRunning else {
            return
        }

        isRunning = false
        watchdogTask?.cancel()
        flushTask?.cancel()
        watchdogTask = nil
        flushTask = nil
        flushBuffers()
        destination = nil
    }

    /// Handles an incoming frame update from the ticker.
    /// - Parameters:
    ///   - timestamp: The timestamp at which this frame was presented.
    ///   - targetTimestamp: The timestamp at which this frame's content should be presented.
    func handleFrame(timestamp: TimeInterval, targetTimestamp: TimeInterval) {
        guard isActive else {
            return
        }

        // Discard a tick produced before the app foregrounded (see activationTimestamp). This runs
        // before the heartbeat and baseline updates so a stale tick neither re-arms the watchdog nor
        // seeds a baseline.
        if let cutoff = activationTimestamp {
            guard timestamp >= cutoff else {
                return
            }

            // First current frame accepted; the cutoff has done its job.
            activationTimestamp = nil
        }

        lastHeartbeatTimestamp = CACurrentMediaTime()

        let cadence = targetTimestamp - timestamp

        guard let previousTarget = previousTargetTimestamp,
            let previousTimestamp = previousFrameTimestamp,
            cadence > 0
        else {
            previousTargetTimestamp = targetTimestamp
            previousFrameTimestamp = timestamp
            return
        }

        // A freeze episode already counted (by the watchdog or by this method) ends with this frame.
        // Don't double-count it as slow or frozen.
        if inFreezeEpisode {
            inFreezeEpisode = false
            previousTargetTimestamp = targetTimestamp
            previousFrameTimestamp = timestamp
            return
        }

        // The inter-frame gap is measured against the previous frame, matching the watchdog's timebase,
        // so both paths agree at the frozen threshold. Lateness is target-relative and drives the slow
        // test, which is about missed presentation deadlines rather than main-thread unresponsiveness.
        let gap = timestamp - previousTimestamp
        let lateness = timestamp - previousTarget

        if gap >= SlowFrameDetector.frozenFrameThreshold {
            frozenFrameCount += 1
        }
        else if lateness >= cadence - SlowFrameDetector.cadenceJitterMargin {
            slowFrameCount += 1
        }

        previousTargetTimestamp = targetTimestamp
        previousFrameTimestamp = timestamp
    }


    // MARK: - Lifecycle Handlers

    func appWillResignActive() {
        // Stop accepting frames immediately, so one still in flight on the detector's frame-consuming
        // task cannot re-arm the heartbeat after this reset.
        isActive = false
        // Prevent watchdog from counting while paused in background.
        lastHeartbeatTimestamp = 0
        inFreezeEpisode = false
        flushBuffers()
    }

    func appDidBecomeActive(at cutoff: TimeInterval) {
        activationTimestamp = cutoff
        previousTargetTimestamp = nil
        previousFrameTimestamp = nil
        lastHeartbeatTimestamp = 0
        inFreezeEpisode = false
        slowFrameCount = 0
        frozenFrameCount = 0
        // Resume accepting frames only after the baseline above is fully reset.
        isActive = true
    }

    func appWillTerminate() {
        flushBuffers()
    }


    // MARK: - Internal Methods

    /// Flushes the collected slow and frozen frame counts to the destination.
    func flushBuffers() {
        guard let destination else {
            return
        }

        // Drain slow frames
        if slowFrameCount > 0 {
            let count = slowFrameCount
            slowFrameCount = 0
            destination.send(type: "slowRenders", count: count, sharedState: nil)
        }

        // Drain frozen frames
        if frozenFrameCount > 0 {
            let count = frozenFrameCount
            frozenFrameCount = 0
            destination.send(type: "frozenRenders", count: count, sharedState: nil)
        }
    }


    // MARK: - Private Methods

    /// Periodically checks if the main thread has been unresponsive (frozen).
    ///
    /// This loop runs continuously in the background, sleeping for the duration of the
    /// frozen frame threshold. If the `lastHeartbeatTimestamp` (updated by `handleFrame`)
    /// has not changed within that time, it indicates a frozen frame. Only one report is made
    /// per continuous freeze episode; `handleFrame` clears `inFreezeEpisode` once frames resume.
    private func runWatchdog() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(SlowFrameDetector.frozenFrameThreshold * 1_000_000_000))
            if Task.isCancelled {
                break
            }
            let now = CACurrentMediaTime()
            if lastHeartbeatTimestamp > 0, !inFreezeEpisode,
                (now - lastHeartbeatTimestamp) >= SlowFrameDetector.frozenFrameThreshold
            {
                frozenFrameCount += 1
                inFreezeEpisode = true
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
            flushBuffers()
        }
    }
}
