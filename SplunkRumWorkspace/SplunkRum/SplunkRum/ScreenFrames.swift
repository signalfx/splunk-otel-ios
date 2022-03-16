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

    private var slowFrameThreshold: CFTimeInterval = 1.0 / 59.0
    private var frozenFrameThreshold: CFTimeInterval = 700.0 / 1000.0

    private var currentIteration: Int = 0
    private var startedTime: CFTimeInterval = CACurrentMediaTime()

    private var slowCount: Int = 0
    private var frozenCount: Int = 0
    private var isFirstIteration: Bool = true
    private var previousTimestamp:CFAbsoluteTime = CACurrentMediaTime()

    override init() {
            super.init()
            isRunning = false
    }

    func startTracking() {
        isRunning = true
        stopTracking() /// make sure to stop a previous running display link
        let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    func stopTracking() {
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc func displayLinkCallback(_ displayLink: CADisplayLink) {

         let currentTime: CFTimeInterval = CACurrentMediaTime()
         if isFirstIteration{
            previousTimestamp = displayLink.targetTimestamp
            isFirstIteration = false
         }
         let duration = displayLink.timestamp - previousTimestamp
         previousTimestamp = displayLink.timestamp
         let elapsedTime = currentTime - startedTime
         let iteration = Int(elapsedTime)
         if currentIteration == iteration {

            if duration > frozenFrameThreshold {
                frozenCount += 1
             } else if duration > slowFrameThreshold {
                slowCount += 1
             }

         } else {

             if slowCount > 0 {
                 reportSlowframe(slowFrameCount: slowCount, name: "slowRenders")
             }

             if frozenCount > 0 {
                 reportSlowframe(slowFrameCount: frozenCount, name: "frozenRenders")
             }
             slowCount = 0
             frozenCount = 0
            currentIteration = iteration
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
