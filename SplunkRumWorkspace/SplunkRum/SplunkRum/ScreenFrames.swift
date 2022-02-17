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
    
    private var previousFrameTimestamp: CFTimeInterval = CACurrentMediaTime()
    private let frozenFrameThreshold: CFTimeInterval = 0.7
    private let previousFrameInitalValue: CFTimeInterval = -1
    private var isRunning = false
    private var displayLink: CADisplayLink?
    private var slowFrameThreshold: CFTimeInterval = CACurrentMediaTime()
    
    override init() {
            super.init()
            isRunning = false
               // If we can't get the frame rate we assume it is 60.
            var maximumFramesPerSecond = 60.0

        if #available(iOS 10.3, *) {
            maximumFramesPerSecond = Double(UIScreen.main.maximumFramesPerSecond)
        }
        slowFrameThreshold = 1 / (maximumFramesPerSecond - 1)

        print(slowFrameThreshold)
    }
    
    func timestamp() -> CFTimeInterval {
        return displayLink?.timestamp ?? 0
    }
    
    func start() {
        isRunning = true
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink?.add(to: .main, forMode: RunLoop.Mode.common)
    }
    
    func stop() {
        isRunning = false
        displayLink?.invalidate()
    }
    
    @objc func displayLinkCallback() {

        let lastFrameTimestamp: CFTimeInterval = timestamp()
            if previousFrameTimestamp == previousFrameInitalValue {
                previousFrameTimestamp = lastFrameTimestamp
                return
            }

        let frameDuration = lastFrameTimestamp - previousFrameTimestamp
          // print(String(format: "%.02f", frameDuration))
        if frameDuration > slowFrameThreshold && frameDuration <= frozenFrameThreshold {
                reportSlowframe(e: frameDuration)
        }

        if frameDuration > frozenFrameThreshold {
            reportSlowframe(e: frameDuration)
        }
 
     }
    
    func reportSlowframe(e: CFTimeInterval) {
        let tracer = buildTracer()
        let now = Date()
        let typeName = "slow.frame"
        let span = tracer.spanBuilder(spanName: typeName).setStartTime(time: now).startSpan()
        span.setAttribute(key: "component", value: "ui")
        span.setAttribute(key: "slow.frame", value: e)
        span.end(time: now)
    }

}




