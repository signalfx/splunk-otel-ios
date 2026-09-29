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

internal import CiscoLogger
@_spi(SplunkInternal) import SplunkCommon
import UIKit

extension AppStart {

    // MARK: - Cold start events

    func coldStartEvents(startTime: Date) -> [AppStartEvent] {
        var events: [AppStartEvent] = []

        events.append(AppStartEvent(name: "process.start", timestamp: startTime))

        if let didFinishLaunchingTimestamp {
            events.append(
                AppStartEvent(
                    name: UIApplication.didFinishLaunchingNotification.rawValue,
                    timestamp: didFinishLaunchingTimestamp
                )
            )
        }

        if let willEnterForegroundTimestamp {
            events.append(
                AppStartEvent(
                    name: UIApplication.willEnterForegroundNotification.rawValue,
                    timestamp: willEnterForegroundTimestamp
                )
            )
        }

        if let didBecomeActiveTimestamp {
            events.append(
                AppStartEvent(
                    name: UIApplication.didBecomeActiveNotification.rawValue,
                    timestamp: didBecomeActiveTimestamp
                )
            )
        }

        return events
    }
}
