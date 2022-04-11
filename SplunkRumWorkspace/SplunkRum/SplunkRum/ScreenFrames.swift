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

    private var displayLink: CADisplayLink?

    private var slowFrameThreshold: CFTimeInterval = SplunkRum.configuredOptions?.slowFrameThreshold ?? 0.0169
    private var frozenFrameThreshold: CFTimeInterval = SplunkRum.configuredOptions?.frozenFrameThreshold ?? 0.7

    private var currentIteration: Int = 0
    private var startedTime: CFTimeInterval = CACurrentMediaTime()

    private var slowCount: Int = 0
    private var frozenCount: Int = 0
    private var isFirstIteration: Bool = true
    private var previousTimestamp: CFTimeInterval = CACurrentMediaTime()

    func startTracking() {

        stopTracking() /// make sure to stop a previous running display link
        let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    func stopTracking() {

        displayLink?.invalidate()
        displayLink = nil
    }

    // timestamp: The time interval that represents when the last frame displayed
    // targetTimestamp: TargetTimestamp is the time of the next frame to trigger the link
    @objc func displayLinkCallback(_ displayLink: CADisplayLink) {

        // In order to manage the long render time, after bringing the app back into the foreground.
         let state = UIApplication.shared.applicationState
         if state == .background || state == .inactive {
            isFirstIteration = true
         }
         let currentTime: CFTimeInterval = CACurrentMediaTime()
         if isFirstIteration {
            previousTimestamp = currentTime
            isFirstIteration = false
         }
        // Report every slow frame as a span, in 1 second intervals, in which the count of slow frames is recorded.
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
             } else {
                 if duration > frozenFrameThreshold {
                     reportSlowframe(slowFrameCount: 1, name: "frozenRenders")
                 }
             }
             slowCount = 0
             frozenCount = 0
             if duration > frozenFrameThreshold {
                 frozenCount += 1
              } else if duration > slowFrameThreshold {
                 slowCount += 1
              }
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
