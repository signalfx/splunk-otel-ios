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
import OpenTelemetrySdk
import OpenTelemetryApi

class SessionBasedSampling {
    static var probability: Double = 1.0
    static var sessionCount: Int = 0
    static var timer: Timer?
    init(ratio: Double) {
        SessionBasedSampling.probability = ratio
    }
    /**check that session will be sampled or not**/
    public class func sessionshouldSample() {
        let sampling_percentage = SessionBasedSampling.probability
        let step = Double(1/sampling_percentage)

        let roundedStepValue = round(step * 10) / 10.0
        var result = false
        switch SessionBasedSampling.probability {
        case 0.0:
            result = false
        case 1.0:
            result = true

        default:
            if floor(Double(SessionBasedSampling.sessionCount).truncatingRemainder(dividingBy: roundedStepValue)) == 0 {  // if SessionBasedSampling.sessionCount % Int(step) == 0 {
                result = true
            } else {
                result = false
            }
        }

        var psampler: Sampler
        if result {
                psampler = OpenTelemetrySdk.Samplers.parentBased(root: Samplers.alwaysOn, remoteParentSampled: Samplers.alwaysOn, remoteParentNotSampled: Samplers.alwaysOn, localParentSampled: Samplers.alwaysOn, localParentNotSampled: Samplers.alwaysOn)
        } else {
              psampler = OpenTelemetrySdk.Samplers.parentBased(root: Samplers.alwaysOff, remoteParentSampled: Samplers.alwaysOff, remoteParentNotSampled: Samplers.alwaysOff, localParentSampled: Samplers.alwaysOff, localParentNotSampled: Samplers.alwaysOff)
        }
        OpenTelemetrySDK.instance.tracerProvider.updateActiveSampler(psampler)
        if SessionBasedSampling.probability != 0.0 && SessionBasedSampling.probability != 1.0 {
            SessionBasedSampling.sessionCount += 1
            SessionBasedSampling.startTimer()
        }

     }
    /**start timer**/
    public class func startTimer() {
        SessionBasedSampling.stopTimer()
        guard self.timer == nil else { return }
        self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(MAX_SESSION_AGE_SECONDS), repeats: true) { _ in
            SessionBasedSampling.sessionshouldSample()
         }

    }
    /** stop timer*/
    public class func stopTimer() {
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
    }
}
