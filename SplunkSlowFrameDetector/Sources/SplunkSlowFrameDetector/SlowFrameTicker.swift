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

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#endif

// MARK: - SlowFrameTicker Protocol

/// An abstraction for a timer that "ticks" on every frame refresh of the display.
///
/// This protocol provides a consistent interface for receiving frame updates, abstracting
/// the underlying mechanism (like `CADisplayLink`) for easier testing and dependency injection.
protocol SlowFrameTicker {
    /// An async closure that is called for each frame update.
    var onFrame: (@MainActor (TimeInterval, TimeInterval) async -> Void)? { get set }

    /// Starts the ticker on the main thread.
    @MainActor
    func start()

    /// Stops the ticker.
    ///
    /// - Note: This method is intentionally not marked with `@MainActor` so it can be safely called from `deinit`.
    /// It handles dispatching to the main thread internally if needed.
    func stop()

    /// Pauses the ticker on the main thread.
    @MainActor
    func pause()

    /// Resumes the ticker on the main thread.
    @MainActor
    func resume()
}

#if os(iOS) || os(tvOS) || os(visionOS)

    // MARK: - DisplayLinkTicker Implementation

    /// A concrete implementation of `SlowFrameTicker` that uses `CADisplayLink`.
    final class DisplayLinkTicker: SlowFrameTicker {

        // MARK: - Public Properties

        /// An async closure that is called for each frame update.
        var onFrame: (@MainActor (TimeInterval, TimeInterval) async -> Void)?

        // MARK: - Private Properties

        private var displayLink: CADisplayLink?

        // MARK: - Initialization

        deinit {
            // As a fail-safe, ensure the display link is invalidated when the ticker is deallocated.
            // The owner is responsible for calling stop() for intentional cleanup.
            stop()
        }

        // MARK: - SlowFrameTicker methods

        @MainActor
        func start() {
            guard displayLink == nil else {
                return
            }

            displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback(_:)))
            displayLink?.add(to: .main, forMode: .common)
        }

        func stop() {
            if Thread.isMainThread {
                displayLink?.invalidate()
                displayLink = nil
            }
            else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    displayLink?.invalidate()
                    displayLink = nil
                }
            }
        }

        @MainActor
        func pause() {
            displayLink?.isPaused = true
        }

        @MainActor
        func resume() {
            displayLink?.isPaused = false
        }

        // MARK: - Private Methods

        @objc
        private func displayLinkCallback(_ link: CADisplayLink) {
            Task {
                await onFrame?(link.timestamp, link.duration)
            }
        }
    }
#endif // os(iOS) || os(tvOS) || os(visionOS)
