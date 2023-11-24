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

struct BoolDecision: Decision {
    var isSampled: Bool
    var attributes: [String: AttributeValue] = [:]
}

class SessionBasedSampler: Sampler {

    var probability: Double = 1.0
    var upperBound: UInt32 = 0xFFFFFFFF
    var currentlySampled: Bool?
    var lock: Lock = Lock()

    init(ratio: Double) {
        probability = ratio
        upperBound = UInt32(floor(ratio * Double(upperBound)))
        observeSessionIdChange()
    }

    // swiftlint:disable function_parameter_count
    func shouldSample(parentContext: SpanContext?, traceId: TraceId, name: String, kind: SpanKind, attributes: [String: AttributeValue], parentLinks: [SpanData.Link]) -> Decision {
        return lock.withLock({
            return self.getDecision()
        })

    }
    // swiftlint:enable function_parameter_count

    var description: String {
        return "SessionBasedSampler, Ratio: \(probability)"
    }

    private func observeSessionIdChange() {
        addSessionIdCallback { [weak self] in
            self?.lock.withLockVoid {
                self?.currentlySampled = self?.shouldSampleNewSession(sessionId: getRumSessionId())
            }
        }
    }

    private func getDecision() -> Decision {
        if let currentlySampled = self.currentlySampled {
            return BoolDecision(isSampled: currentlySampled)
        }

        let isSampled = self.shouldSampleNewSession(sessionId: getRumSessionId())
        self.currentlySampled = isSampled
        return BoolDecision(isSampled: isSampled)
    }

    /**Check if session will be sampled or not.**/
    private func shouldSampleNewSession(sessionId: String) -> Bool {
        var result = false

        switch probability {
        case 0.0:
            result = false
        case 1.0:
            result = true
        default:
            result = sessionIdValue(sessionId: sessionId) < self.upperBound
        }

        return result
    }
}

func sessionIdValue(sessionId: String) -> UInt32 {
    if sessionId.count < 32 {
        return 0
    }

    var acc: UInt32 = 0

    for i in stride(from: 0, to: sessionId.count, by: 8) {
        let beginIndex = sessionId.index(sessionId.startIndex, offsetBy: i)
        let endIndex = sessionId.index(beginIndex, offsetBy: 8, limitedBy: sessionId.endIndex) ?? sessionId.endIndex
        let val = UInt32(sessionId[beginIndex ..< endIndex], radix: 16) ?? 0
        acc ^= val
    }

    return acc
}
