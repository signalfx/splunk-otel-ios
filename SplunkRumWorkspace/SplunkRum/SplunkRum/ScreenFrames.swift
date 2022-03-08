//
/*
Copyright 2021 Splunk Inc.

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

class ScreenFrames: NSObject {

    private var isRunning = false
    private var displayLink: CADisplayLink?
    /// Anything less than 59 FPS is slow.
    private var slowFrameThreshold: CFTimeInterval = 16
    private var frozenFrameThreshold: CFTimeInterval = 700

    private var slowCount: Int = 0
    private var frozenCount: Int = 0
    private var startedTime: CFTimeInterval = CACurrentMediaTime()

    override init() {
            super.init()
            isRunning = false
    }

    func startTracking() {
        isRunning = true
        stopTracking() /// make sure to stop a previous running display link
        let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink.preferredFramesPerSecond = SplunkRum.configuredOptions?.framesPerSecond ?? 0  /// (optional) if you do not define , then device uses maxFramesPS
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    func stopTracking() {
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc func displayLinkCallback(_ displayLink: CADisplayLink) {

         if self.startedTime == 0.0 {
            self.startedTime = CFAbsoluteTimeGetCurrent()
            return
         }

         let currentTime: CFTimeInterval = CACurrentMediaTime()
         let elapsedTime = currentTime - startedTime

         let count = 1 / (displayLink.targetTimestamp - displayLink.timestamp)

        if elapsedTime > slowFrameThreshold {
             stopTracking()
             slowCount += Int(count)
        }
        if elapsedTime > frozenFrameThreshold {
            stopTracking()
            frozenCount += Int(count)
        }

        if slowCount > 0 {
            reportSlowframe(slowFrameCount: slowCount, name: "slowRenders")
        }
        if frozenCount > 0 {
            reportSlowframe(slowFrameCount: frozenCount, name: "frozenRenders")
        }
     }

    func reportSlowframe(slowFrameCount: Int, name: String) {
        let tracer = buildTracer()
        let now = Date()
        let typeName = name
        let span = tracer.spanBuilder(spanName: typeName).setStartTime(time: now).startSpan()
        span.setAttribute(key: "component", value: "ui")
        span.setAttribute(key: "count", value: slowFrameCount)
        span.setAttribute(key: "screen.name", value: getScreenName())
        span.end(time: now)
    }

}
