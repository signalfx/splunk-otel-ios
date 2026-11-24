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
    internal import SplunkCrashReports

    extension SplunkRum {

        /// Keeps crash capture current while the saved starts are read.
        ///
        /// Processing can delete the previous crash's pending report, so wait until its session's
        /// held start can be released.
        func startCrashReportProcessing(in crashReportsModule: SplunkCrashReports.CrashReports) {
            keepCrashReportSessionIdCurrent(in: crashReportsModule)

            let processPendingReport: () -> Void = { [weak crashReportsModule] in
                crashReportsModule?.reportCrashIfPresent()
            }

            if let session = currentSession as? DefaultSession {
                session.whenHeldSessionStartsRestored(processPendingReport)
            }
            else {
                DispatchQueue.main.async(execute: processPendingReport)
            }
        }

        /// Gives the crash reporter the current session ID now and after every session change.
        ///
        /// A crash right after installation or after a session change then carries the ID of the
        /// session in which it happened.
        func keepCrashReportSessionIdCurrent(in crashReportsModule: SplunkCrashReports.CrashReports) {
            crashReportsSessionObserver = Self.observeSessionChanges(for: crashReportsModule)

            crashReportsModule.refreshCachedSessionId()
        }

        /// Refreshes the session ID cached for a future crash report every time the session changes.
        ///
        /// Returns the observer token. The agent keeps it and removes the observer when it is released.
        static func observeSessionChanges(for crashReportsModule: SplunkCrashReports.CrashReports) -> NSObjectProtocol {
            NotificationCenter.default.addObserver(
                forName: DefaultSession.sessionDidResetNotification,
                object: nil,
                queue: nil
            ) { [weak crashReportsModule] _ in
                crashReportsModule?.refreshCachedSessionId()
            }
        }
    }

#endif
