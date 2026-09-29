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

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#endif

class AppStateManager: AgentAppStateManager {

    // MARK: - Internal properties

    private var appStateModel: AppStateModel

    /// Serializes external access to stored data.
    private let accessQueue: DispatchQueue

    private let lifecycleRecorder: AppLifecycleRecorder?
    private var lifecycleObserverIdentifier: UUID?

    // MARK: - Initialization

    init(
        appStateModel: AppStateModel = AppStateModel(),
        lifecycleRecorder: AppLifecycleRecorder? = nil
    ) {
        self.appStateModel = appStateModel
        self.lifecycleRecorder = lifecycleRecorder

        let queueName = PackageIdentifier.default(named: "appStateAccess")
        accessQueue = DispatchQueue(label: queueName)

        if let lifecycleRecorder {
            lifecycleObserverIdentifier = lifecycleRecorder.addObserver { [weak self] update in
                guard let self else {
                    return
                }

                if update.event == nil {
                    processLifecycleEvents(update.snapshot.events.map(\.event))
                    return
                }

                guard let event = update.event else {
                    return
                }

                processLifecycleEvents([event])
            }
        }
        else {
            hookToAppLifecycle()
        }
    }

    private func processLifecycleEvents(_ lifecycleEvents: [AppLifecycleRecorder.Event]) {
        accessQueue.sync {
            let events = lifecycleEvents.compactMap { event -> (state: AppState, timestamp: Date)? in
                switch event {
                case let .didBecomeActive(timestamp):
                    return (.active, timestamp)

                case let .didEnterBackground(timestamp):
                    return (.background, timestamp)

                case let .willEnterForeground(timestamp):
                    return (.foreground, timestamp)

                case let .willResignActive(timestamp):
                    return (.inactive, timestamp)

                case let .willTerminate(timestamp):
                    return (.terminate, timestamp)

                case .didFinishLaunching:
                    return nil
                }
            }

            appStateModel.saveEvents(events)
        }
    }

    deinit {
        if let lifecycleObserverIdentifier,
            let lifecycleRecorder
        {
            lifecycleRecorder.removeObserver(lifecycleObserverIdentifier)
        }
    }


    // MARK: - Private functions

    private func hookToAppLifecycle() {
        #if os(iOS) || os(tvOS) || os(visionOS)

            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                self?.processLifecycleEvents([.didBecomeActive(Date())])
            }

            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                self?.processLifecycleEvents([.didEnterBackground(Date())])
            }

            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                self?.processLifecycleEvents([.willEnterForeground(Date())])
            }

            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                self?.processLifecycleEvents([.willResignActive(Date())])
            }

            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                self?.processLifecycleEvents([.willTerminate(Date())])
            }

        #endif
    }


    // MARK: - Public functions

    func appState(for timestamp: Date) -> AppState? {
        accessQueue.sync {
            appStateModel.appState(for: timestamp)
        }
    }
}
