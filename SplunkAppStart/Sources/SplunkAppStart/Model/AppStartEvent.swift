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

import Foundation

/// Represents a single timed event.
struct AppStartEvent {
    let name: String
    let timestamp: Date
}

extension AppStartEvent {

    /// Sorts events by timestamp.
    static func sortedEvents(from events: [String: Date]) -> [AppStartEvent] {
        let appStartEvents = events.map { name, timestamp in
            AppStartEvent(name: name, timestamp: timestamp)
        }.sorted { $0.timestamp < $1.timestamp }

        return appStartEvents
    }
}
