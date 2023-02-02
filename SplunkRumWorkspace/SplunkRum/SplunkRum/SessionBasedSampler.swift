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

class SessionBasedSampler {
    static var probability: Double = 1.0
    private let sessionIdCallback: (() -> Void) = {
        sessionShouldSample()
    }

    init(ratio: Double) {
        SessionBasedSampler.probability = ratio
        addSessionIdCallback(sessionIdCallback)
    }

    /**Check if session will be sampled or not.**/
    @discardableResult public class func sessionShouldSample() -> Bool {

        var result = false
        switch SessionBasedSampler.probability {
        case 0.0:
            result = false
        case 1.0:
            result = true
        default:
            result = Double.random(in: 0.0...1.0) <= SessionBasedSampler.probability
        }

        var parentSampler: Sampler
        if result {
            parentSampler = Samplers.parentBased(root: Samplers.alwaysOn, remoteParentSampled: Samplers.alwaysOn, remoteParentNotSampled: Samplers.alwaysOn, localParentSampled: Samplers.alwaysOn, localParentNotSampled: Samplers.alwaysOn)
        } else {
            parentSampler = Samplers.parentBased(root: Samplers.alwaysOff, remoteParentSampled: Samplers.alwaysOff, remoteParentNotSampled: Samplers.alwaysOff, localParentSampled: Samplers.alwaysOff, localParentNotSampled: Samplers.alwaysOff)
        }

        let tracerProvider = OpenTelemetry.instance.tracerProvider as! TracerProviderSdk
        tracerProvider.updateActiveSampler(parentSampler)
        return result
    }

}
