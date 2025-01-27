//
/*
Copyright 2024 Splunk Inc.

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
@_implementationOnly import SplunkLogger

class AppStateModel {

    // MARK: - Static constants

    private static let storageKey = "appStateEvents"

    /// Maximum number of stored app state events.
    private static let maxEvents = 100

    /// Maximum lifetime of stored app states. The value corresponds to 30 days.
    private static let eventLifetime: TimeInterval = 2_592_000


    // MARK: - Internal properties

    private let storage: KeyValueStorage
    private let internalLogger = InternalLogger(configuration: .agent(category: "AppStateModel"))


    // MARK: - Initialization

    init(storage: KeyValueStorage = UserDefaultsStorage()) {
        self.storage = storage
    }

    // MARK: - Public functions

    func saveEvent(_ state: AppState) {
        let now = Date()
        var events: [AppStateEvent] = (try? storage.read(forKey: Self.storageKey)) ?? []

        // Remove events which are old
        events = events.filter {
            now.timeIntervalSince($0.timestamp) <= Self.eventLifetime
        }

        // Remove events which exceeds maximal event count
        if events.count >= Self.maxEvents {
            events.removeFirst(events.count - Self.maxEvents + 1)
        }

        // Add new event
        let newState = AppStateEvent(timestamp: now, state: state)
        events.append(newState)

        // Save events to storage
        do {
            try storage.update(events, forKey: Self.storageKey)
        } catch {
            internalLogger.log(level: .error) {
                "Error when updating AppStateEvents in storage with error message \(error.localizedDescription)."
            }
        }
    }

    func appState(for timestamp: Date) -> AppState? {
        do {
            let events: [AppStateEvent]? = try storage.read(forKey: Self.storageKey)

            // Events are sorted by date, just take first in reversed array before given date
            let foundEvent = events?.reversed().first(where: { $0.timestamp < timestamp })

            return foundEvent?.state
        } catch {
            internalLogger.log(level: .error) {
                "Error when fetching AppStateEvents from storage with error message \(error.localizedDescription)."
            }

            return nil
        }
    }
}
