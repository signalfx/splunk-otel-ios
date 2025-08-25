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
import SplunkCommon

public final class AppStateModule {

    // MARK: - Public properties

    public unowned var sharedState: AgentSharedState?


    // MARK: - Internal properties

    var notificationObservers: [NSObjectProtocol] = []
    var destination: AppStateDestination = OtelDestination()


    // MARK: - Initialization

    public required init() {}

    deinit {
        removeNotifications()
    }


    // MARK: - Start/Stop Detection

    func startDetection() {
        setupNotifications()
    }

    func stopDetection() {
        removeNotifications()
    }


    // MARK: - Process events

    func processEvent(_ event: AppStateType) {
        destination.send(appState: event, time: Date(), sharedState: sharedState)
    }
}
