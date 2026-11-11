//
/*
Copyright 2026 Splunk Inc.

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
internal import SplunkCrashReporter

enum ReactNativeFatalMarkerConstants {
    static let schema = "1"
    static let validityInterval: TimeInterval = 2
    // PLCrashReporter stores the crash timestamp with whole-second precision.
    // A marker created later in that same second can therefore appear to be up
    // to one second in the future when the report is read on the next launch.
    static let crashTimestampResolution: TimeInterval = 1
    static let maximumClockSkew: TimeInterval = 0.25
}

extension CrashReports {
    func shouldSuppressReactNativeFatalCrash(report: SPLKPLCrashReport) -> Bool {
        shouldSuppressReactNativeFatalCrash(
            customData: report.customData,
            crashTimestamp: report.systemInfo?.timestamp
        )
    }

    func shouldSuppressReactNativeFatalCrash(customData: Data?, crashTimestamp: Date?) -> Bool {
        guard
            let customData,
            let crashTimestamp,
            let dictionary = decodeReactNativeFatalCustomData(customData),
            dictionary[CrashReportCustomDataKeys.reactNativeFatalSchema.rawValue] ==
                ReactNativeFatalMarkerConstants.schema,
            let spanId = dictionary[CrashReportCustomDataKeys.reactNativeFatalSpanId.rawValue],
            isValidReactNativeFatalSpanId(spanId),
            let armedAtString = dictionary[CrashReportCustomDataKeys.reactNativeFatalArmedAtEpochMs.rawValue],
            let armedAtEpochMs = Int64(armedAtString)
        else {
            return false
        }

        let armedAt = Date(timeIntervalSince1970: TimeInterval(armedAtEpochMs) / 1_000)
        let elapsed = crashTimestamp.timeIntervalSince(armedAt)
        let maximumNegativeElapsed = ReactNativeFatalMarkerConstants.crashTimestampResolution
            + ReactNativeFatalMarkerConstants.maximumClockSkew
        let shouldSuppress = elapsed >= -maximumNegativeElapsed
            && elapsed <= ReactNativeFatalMarkerConstants.validityInterval

        if !shouldSuppress {
            logger.log(level: .warn) {
                "Ignored React Native fatal marker outside the crash correlation window "
                    + "(elapsed: \(elapsed) seconds)."
            }
        }

        return shouldSuppress
    }

    func isValidReactNativeFatalSpanId(_ spanId: String) -> Bool {
        spanId.count == 16 && spanId.allSatisfy(\.isHexDigit)
    }

    private func decodeReactNativeFatalCustomData(_ data: Data) -> [String: String]? {
        do {
            if #available(iOS 14.0, tvOS 14.0, macCatalyst 14.0, *) {
                return try NSKeyedUnarchiver.unarchivedDictionary(
                    ofKeyClass: NSString.self,
                    objectClass: NSString.self,
                    from: data
                ) as? [String: String]
            }

            return try NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSDictionary.self, NSString.self],
                from: data
            ) as? [String: String]
        }
        catch {
            logger.log(level: .warn) {
                "Could not decode the React Native fatal crash marker: \(error)"
            }
            return nil
        }
    }
}
