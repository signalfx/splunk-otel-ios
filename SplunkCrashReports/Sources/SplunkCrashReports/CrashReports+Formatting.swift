//
/*
Copyright 2025 Splunk Inc.

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

import CrashReporter
import Foundation

// Report formatting extension

extension CrashReports {

    /// Report formatting.
    func formatCrashReport(report: PLCrashReport) -> [CrashReportKeys: Any] {

        var reportDict: [CrashReportKeys: Any] = [:]

        reportDict[.component] = "crash"
        reportDict[.error] = true

        if let systemInfo = report.systemInfo {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
            reportDict[.crashTimestamp] = formatter.string(from: systemInfo.timestamp)
            reportDict[.currentTimestamp] = formatter.string(from: Date())
        }

        if report.hasProcessInfo {
            reportDict[.processPath] = report.processInfo.processPath
            reportDict[.isNative] = report.processInfo.native
        }

        if let signalInfo = report.signalInfo {
            reportDict[.signalName] = signalInfo.name
            reportDict[.faultAddress] = String(signalInfo.address)
        }

        if report.hasExceptionInfo {
            reportDict[.exceptionName] = report.exceptionInfo.exceptionName ?? ""
            reportDict[.exceptionReason] = report.exceptionInfo.exceptionReason ?? ""
        }

        addCustomData(from: report, to: &reportDict)

        // Collect threads with stack frames
        let reportThreads = allThreadsFromCrashReport(report: report)
        reportDict[.threads] = threadList(threads: reportThreads)

        // Images referenced in threads
        reportDict[.images] = imageList(images: report.images)

        // App state
        reportDict[.previousAppState] = appStateHandler(report: report)

        return reportDict
    }

    func addCustomData(from report: PLCrashReport, to reportDict: inout [CrashReportKeys: Any]) {
        guard let customData = report.customData else {
            return
        }

        do {
            let unarchivedData: [String: String]?
            if #available(iOS 14.0, *) {
                unarchivedData =
                    try NSKeyedUnarchiver.unarchivedDictionary(
                        ofKeyClass: NSString.self,
                        objectClass: NSString.self,
                        from: customData
                    ) as? [String: String]
            }
            else {
                // Fallback for iOS 13 using the secure unarchiver available since iOS 11
                unarchivedData =
                    try NSKeyedUnarchiver.unarchivedObject(
                        ofClasses: [NSDictionary.self, NSString.self],
                        from: customData
                    ) as? [String: String]
            }

            if let data = unarchivedData {
                if let sessionId = data["sessionId"] {
                    reportDict[.sessionId] = sessionId
                }

                reportDict[.batteryLevel] = data["battery"]
                reportDict[.freeMemory] = data["disk"]
                reportDict[.freeDiskSpace] = data["memory"]
                reportDict[.screenName] = data["screenName"]
            }
        }
        catch {
            logger.log(level: .warn) {
                "Crash reporter could not report custom data, error: \(error)"
            }
        }
    }
}
