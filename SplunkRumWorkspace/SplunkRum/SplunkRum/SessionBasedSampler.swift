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

class SessionBasedSampler {
    static var probability: Double = 1.0
    static var sessionCount: Int = 0
    static var timer: Timer?

    init(ratio: Double) {
        SessionBasedSampler.probability = ratio
    }

    public class func sessionShouldSample() {
        let samplingPercentage = SessionBasedSampler.probability
        let step = Double(1/samplingPercentage)
        let roundedStepValue = round(step * 10) / 10.0

        var result = false
        switch SessionBasedSampler.probability {
        case 0.0:
            result = false
        case 1.0:
            result = true
        default:
            if floor(Double(SessionBasedSampler.sessionCount).truncatingRemainder(dividingBy: roundedStepValue)) == 0{
                result = true
            } else {
                result = false
            }
        }

        var parentSampler: Sampler
        if result {
            parentSampler = OpenTelemetrySdk.Samplers.parentBased(root: Samplers.alwaysOn, remoteParentSampled: Samplers.alwaysOn, remoteParentNotSampled: Samplers.alwaysOn, localParentSampled: Samplers.alwaysOn, localParentNotSampled: Samplers.alwaysOn)
        } else {
            parentSampler = OpenTelemetrySdk.Samplers.parentBased(root: Samplers.alwaysOff, remoteParentSampled: Samplers.alwaysOff, remoteParentNotSampled: Samplers.alwaysOff, localParentSampled: Samplers.alwaysOff, localParentNotSampled: Samplers.alwaysOff)
        }

        OpenTelemetrySDK.instance.tracerProvider.updateActiveSampler(parentSampler)
        if SessionBasedSampler.probability != 0.0 && SessionBasedSampler.probability != 1.0 {
            SessionBasedSampler.sessionCount += 1
            SessionBasedSampler.startTimer()
        }
    }

    public class func startTimer() {
        SessionBasedSampler.stopTimer()
        guard self.timer == nil else { return }
        self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(MAX_SESSION_AGE_SECONDS), repeats: true) { _ in
            SessionBasedSampler.sessionShouldSample()
        }
    }

    public class func stopTimer() {
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
    }

}