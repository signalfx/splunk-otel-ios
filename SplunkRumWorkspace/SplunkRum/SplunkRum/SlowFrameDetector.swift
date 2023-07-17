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

fileprivate var detector: SlowFrameDetector = SlowFrameDetector()

class SlowFrameDetector: NSObject {

    private var displayLink: CADisplayLink?
    private var slowFrames: [String: Int] = [:]
    private var frozenFrames: [String: Int] = [:]

    fileprivate var slowFrameThreshold: CFTimeInterval = 16.7
    fileprivate var frozenFrameThreshold: CFTimeInterval = 700

    private var previousTimestamp: CFTimeInterval = 0.0
    private var currentScreenName = getScreenName()
    private var timer = Timer()

    func start() {
        if self.displayLink != nil {
            return
        }

        SplunkRum.addScreenNameChangeCallback { name in
            self.currentScreenName = name
        }

        NotificationCenter.default.addObserver(self, selector: #selector(self.appWillResignActive(notification:)), name: UIApplication.willResignActiveNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.appDidBecomeActive(notification:)), name: UIApplication.didBecomeActiveNotification, object: nil)

        let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink

        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            self.dumpFrames()
        })
    }

    @objc func appWillResignActive(notification: Notification) {
        self.displayLink?.isPaused = true
        dumpFrames()
    }

    @objc func appDidBecomeActive(notification: Notification) {
        previousTimestamp = 0.0
        self.displayLink?.isPaused = false
    }

    @objc func displayLinkCallback(_ displayLink: CADisplayLink) {
        if previousTimestamp == 0.0 {
            previousTimestamp = displayLink.timestamp
            return
        }

        let duration = displayLink.timestamp - previousTimestamp
        previousTimestamp = displayLink.timestamp

        let frozenThresholdSeconds = frozenFrameThreshold / 1e3
        let slowThresholdSeconds = slowFrameThreshold / 1e3
        if duration >= frozenThresholdSeconds {
            if let count = self.frozenFrames[currentScreenName] {
                self.frozenFrames[currentScreenName] = count + 1
            } else {
                self.frozenFrames[currentScreenName] = 1
             }
         } else if duration >= slowThresholdSeconds {
             if let count = self.slowFrames[currentScreenName] {
                 self.slowFrames[currentScreenName] = count + 1
             } else {
                 self.slowFrames[currentScreenName] = 1
             }
         }
     }

    func dumpFrames() {
        for (screenName, count) in self.slowFrames {
            reportFrame("slowRenders", screenName, count)
        }

        for (screenName, count) in self.frozenFrames {
            reportFrame("frozenRenders", screenName, count)
        }

        self.slowFrames.removeAll()
        self.frozenFrames.removeAll()
    }

    func reportFrame(_ type: String, _ screenName: String, _ count: Int) {
        let tracer = buildTracer()
        let now = Date()
        let span = tracer.spanBuilder(spanName: type).setStartTime(time: now).startSpan()
        span.setAttribute(key: Constants.AttributeNames.COMPONENT, value: "ui")
        span.setAttribute(key: Constants.AttributeNames.COUNT, value: count)
        span.setAttribute(key: Constants.AttributeNames.SCREEN_NAME, value: screenName)
        span.end(time: now)
    }
}

func startSlowFrameDetector(slowFrameDetectionThresholdMs: Double?, frozenFrameDetectionThresholdMs: Double?) {
    if slowFrameDetectionThresholdMs != nil {
        detector.slowFrameThreshold = slowFrameDetectionThresholdMs!
    }

    if frozenFrameDetectionThresholdMs != nil {
        detector.frozenFrameThreshold = frozenFrameDetectionThresholdMs!
    }

    detector.start()
}
