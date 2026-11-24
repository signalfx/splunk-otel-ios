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

#if canImport(SplunkCrashReports)

    import Foundation
    import XCTest

    @testable import SplunkAgent
    @testable import SplunkCrashReports

    final class RestorationCrashReportsSpy: CrashReports {

        /// Models the pending report that survives a process restart until it is consumed.
        final class PendingReport {
            var sessionId: String?

            init(sessionId: String) {
                self.sessionId = sessionId
            }
        }

        weak var session: DefaultSession?
        var pendingReport: PendingReport?
        private(set) var processingCount = 0

        var cachedSessionId: String? {
            guard let data = crashReporter?.customData else {
                return nil
            }

            let customData =
                try? NSKeyedUnarchiver.unarchivedObject(
                    ofClasses: [NSDictionary.self, NSString.self],
                    from: data
                ) as? [String: String]

            return customData?[CrashReportCustomDataKeys.sessionId.rawValue]
        }

        override func reportCrashIfPresent() {
            XCTAssertTrue(Thread.isMainThread)
            processingCount += 1

            guard let pendingReport, let sessionId = pendingReport.sessionId else {
                return
            }

            session?.trackAcceptedTelemetry(forSessionId: sessionId)
            pendingReport.sessionId = nil
        }
    }

#endif
