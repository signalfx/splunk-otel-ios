//
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
import UIKit

// MARK: - SlowFrameTicker for Testability

/// An abstraction for a timer that "ticks" on every frame refresh of the display.
///
/// This protocol provides a consistent interface for receiving frame updates via a regular signal, abstracting the underlying mechanism (like `CADisplayLink`) to allow for easier testing and dependency injection.
internal protocol SlowFrameTicker {
    var onFrame: ((_ timestamp: TimeInterval, _ duration: TimeInterval) -> Void)? { get set }
    func start()
    func stop()
    func pause()
    func resume()
}

internal final class DisplayLinkTicker: SlowFrameTicker {
    private var displayLink: CADisplayLink?
    var onFrame: ((TimeInterval, TimeInterval) -> Void)?

    func start() {
        DispatchQueue.main.async {
            guard self.displayLink == nil else { return }
            self.displayLink = CADisplayLink(target: self, selector: #selector(self.displayLinkCallback(_:)))
            self.displayLink?.add(to: .main, forMode: .common)
        }
    }

    func stop() {
        DispatchQueue.main.async {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
    }

    func pause() {
        DispatchQueue.main.async { self.displayLink?.isPaused = true }
    }

    func resume() {
        DispatchQueue.main.async { self.displayLink?.isPaused = false }
    }

    @objc private func displayLinkCallback(_ link: CADisplayLink) {
        onFrame?(link.timestamp, link.duration)
    }
}
