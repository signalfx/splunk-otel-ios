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
@_spi(SplunkInternal) import SplunkCommon

extension CrashReports {
    func finishPersistenceAttempt() {
        persistenceLock.lock()
        isAwaitingPersistence = false
        persistenceLock.unlock()
    }

    func beginPersistenceAttempt() -> Bool {
        persistenceLock.lock()
        defer {
            persistenceLock.unlock()
        }

        guard !isAwaitingPersistence else {
            return false
        }

        isAwaitingPersistence = true
        return true
    }

    func requestCrashReportPersistence(
        crashReport: [CrashReportKeys: Any],
        sharedState: (any AgentSharedState)?,
        timestamp: Date
    ) {
        guard let crashReportPersistenceHandler else {
            finishPersistenceAttempt()
            logger.log(level: .error) {
                "Crash Report retained because durable span persistence is unavailable."
            }
            return
        }

        crashReportPersistenceHandler(
            { [weak self] in
                guard let self else {
                    return .invalid
                }

                return send(
                    crashReport: crashReport,
                    sharedState: sharedState,
                    timestamp: timestamp
                )
            },
            { [weak self] succeeded in
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }

                    if succeeded {
                        self.crashReporter?.purgePendingCrashReport()
                    }
                    else {
                        self.logger.log(level: .error) {
                            "Crash Report retained because its span could not be persisted."
                        }
                    }

                    self.finishPersistenceAttempt()
                }
            }
        )
    }
}
