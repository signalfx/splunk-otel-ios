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

class ScreenFrames: NSObject {

    private var latestTimeUpdated: CFTimeInterval = CACurrentMediaTime()
    private var startedTime: CFTimeInterval = CACurrentMediaTime()

    private var frameCount: Int = 0
    private var currentIteration: Int = 0

    private var displayLink: CADisplayLink!

    private func setUpDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink.preferredFramesPerSecond = 60
        startedTime = CACurrentMediaTime()
        displayLink.add(to: .main, forMode: RunLoop.Mode.common)
    }

    @objc private func update() {
       
        let currentTime: CFTimeInterval = CACurrentMediaTime()
        let timeElapsed: Double = currentTime - startedTime

        let iteration = Int(timeElapsed)
        if currentIteration == iteration {
            frameCount += 1
        } else {

            frameCount = 0
            currentIteration = iteration
        }

        latestTimeUpdated = currentTime

    }
}
