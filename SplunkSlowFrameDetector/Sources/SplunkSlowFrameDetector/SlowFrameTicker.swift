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


// MARK: - SlowFrameTicker for Testability

/// An abstraction for a timer that "ticks" on every frame refresh of the display.
///
/// This protocol provides a consistent interface for receiving frame updates via a regular signal,
/// abstracting the underlying mechanism (like `CADisplayLink`) to allow for easier testing and dependency injection.
protocol SlowFrameTicker {
    var onFrame: ((_ timestamp: TimeInterval, _ duration: TimeInterval) -> Void)? { get set }

    @MainActor
    func start()

    func stop() // Intentionally not @MainActor so it can be used in deinit

    @MainActor
    func pause()

    @MainActor
    func resume()
}

#if os(iOS) || os(tvOS) || os(visionOS)
final class DisplayLinkTicker: SlowFrameTicker {
    private var displayLink: CADisplayLink?
    var onFrame: ((_ timestamp: TimeInterval, _ duration: TimeInterval) -> Void)?

    deinit {
        // As a fail-safe, ensure the display link is invalidated when the ticker is deallocated.
        // The owner is responsible for calling stop() for intentional cleanup.
        stop()
    }

    @MainActor
    func start() {
        guard self.displayLink == nil else { return }
        self.displayLink = CADisplayLink(target: self, selector: #selector(self.displayLinkCallback(_:)))
        self.displayLink?.add(to: .main, forMode: .common)
    }

    // Not @MainActor, to allow calling from deinit
    func stop() {
        if Thread.isMainThread {
            self.displayLink?.invalidate()
            self.displayLink = nil
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.displayLink?.invalidate()
                self.displayLink = nil
            }
        }
    }

    @MainActor
    func pause() {
        self.displayLink?.isPaused = true
    }

    @MainActor
    func resume() {
        self.displayLink?.isPaused = false
    }

    @objc private func displayLinkCallback(_ link: CADisplayLink) {
        onFrame?(link.timestamp, link.duration)
    }
}
#endif // os(iOS) || os(tvOS) || os(visionOS)
