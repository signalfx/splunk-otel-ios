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
    private var slowFrameThreshold:CFTimeInterval = 1.0 / 59.0;
    private var frozenFrameThreshold:CFTimeInterval = 700.0 / 1000.0;
    
   /// The ideal time interval between screen refresh updates.
    private var duration = CFTimeInterval()

   /// The time value associated with the previous frame.
    private var timestamp = CFTimeInterval()

    /// The time value associated with the current frame.
    private var targetTimestamp = CFTimeInterval()

   /// Returns the time in seconds since the last frame was dispatched.
    private var intervalSinceLastFrame = CFTimeInterval()
    
    override init() {
            super.init()
            isRunning = false
    }
    
    func startTracking() {
        isRunning = true
        stopTracking() /// make sure to stop a previous running display link
        let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink.preferredFramesPerSecond = 60
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }
    
    func stopTracking() {
        isRunning = false
        displayLink?.invalidate()
    }
    
    @objc func displayLinkCallback(_ displayLink: CADisplayLink) {
        
        duration = displayLink.targetTimestamp - displayLink.timestamp
        if (duration > slowFrameThreshold) {
            stopTracking()
            reportSlowframe(e: duration)
            
        }
        if (duration > frozenFrameThreshold) {
            stopTracking()
            reportfrozenframe(e: duration)
        }
 
     }
    
    func reportSlowframe(e: CFTimeInterval) {
        let tracer = buildTracer()
        let now = Date()
        let typeName = "slowRenders"
        let span = tracer.spanBuilder(spanName: typeName).setStartTime(time: now).startSpan()
        span.setAttribute(key: "component", value: "ui")
        span.setAttribute(key: "slow.frame", value: e)
        span.end(time: now)
    }
    
    func reportfrozenframe(e: CFTimeInterval) {
        let tracer = buildTracer()
        let now = Date()
        let typeName = "frozenRenders"
        let span = tracer.spanBuilder(spanName: typeName).setStartTime(time: now).startSpan()
        span.setAttribute(key: "component", value: "ui")
        span.setAttribute(key: "frozen.frame", value: e)
        span.end(time: now)
    }

}




