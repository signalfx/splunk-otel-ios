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
@_spi(SplunkInternal) internal import SplunkCommon

public final class AppStateModule {

    // MARK: - Public properties

    public unowned var sharedState: AgentSharedState?


    // MARK: - Internal properties

    var notificationObservers: [NSObjectProtocol] = []
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
        removeNotifications()
        self.lifecycleRecorder = lifecycleRecorder

        lifecycleObserverIdentifier = lifecycleRecorder.addObserver { [weak self] update in
            guard let event = update.event else {
                return
            }

            switch event {
            case let .didBecomeActive(timestamp):
                self?.processEvent(.active, at: timestamp)

            case let .didEnterBackground(timestamp):
                self?.processEvent(.background, at: timestamp)

            case let .willEnterForeground(timestamp):
                self?.processEvent(.foreground, at: timestamp)

            case let .willResignActive(timestamp):
                self?.processEvent(.inactive, at: timestamp)

            case let .willTerminate(timestamp):
                self?.processEvent(.terminate, at: timestamp)

            case .didFinishLaunching:
                break
            }
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
