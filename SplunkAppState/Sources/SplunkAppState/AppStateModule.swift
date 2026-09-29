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
@_spi(SplunkInternal) import SplunkCommon

public final class AppStateModule {

    // MARK: - Public properties

    public unowned var sharedState: AgentSharedState?


    // MARK: - Internal properties

    var notificationObservers: [NSObjectProtocol] = []
    var localObservationStartedAt: Date?
    var lifecycleObserverIdentifier: UUID?
    var lifecycleRecorder: AppLifecycleRecorder?
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

    /// Uses the agent-core lifecycle recorder as the single source of lifecycle events.
    @_spi(SplunkInternal)
    public func use(lifecycleRecorder: AppLifecycleRecorder) {
        guard self.lifecycleRecorder !== lifecycleRecorder else {
            return
        }

        let localObservationStartedAt = localObservationStartedAt
        removeNotifications()
        self.lifecycleRecorder = lifecycleRecorder

        lifecycleObserverIdentifier = lifecycleRecorder.addObserver { [weak self] update in
            guard let self else {
                return
            }

            if update.event == nil {
                let records = update.snapshot.events.filter { record in
                    guard let localObservationStartedAt else {
                        return true
                    }

                    return record.timestamp < localObservationStartedAt
                }

                for record in records {
                    processCoreLifecycleEvent(record.event)
                }
                return
            }

            guard let event = update.event else {
                return
            }

            processCoreLifecycleEvent(event)
        }
    }

    private func processCoreLifecycleEvent(_ event: AppLifecycleRecorder.Event) {
        switch event {
        case let .didBecomeActive(timestamp):
            processEvent(.active, at: timestamp)

        case let .didEnterBackground(timestamp):
            processEvent(.background, at: timestamp)

        case let .willEnterForeground(timestamp):
            processEvent(.foreground, at: timestamp)

        case let .willResignActive(timestamp):
            processEvent(.inactive, at: timestamp)

        case let .willTerminate(timestamp):
            processEvent(.terminate, at: timestamp)

        case .didFinishLaunching:
            break
        }
    }


    // MARK: - Process events

    func processEvent(_ event: AppStateType) {
        processEvent(event, at: Date())
    }

    func processEvent(_ event: AppStateType, at time: Date) {
        destination.send(appState: event, time: time, sharedState: sharedState)
    }
}
