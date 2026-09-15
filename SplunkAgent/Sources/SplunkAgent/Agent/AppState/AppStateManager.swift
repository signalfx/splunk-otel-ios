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
                guard let event = update.event else {
                    return
                }

                switch event {
                case let .didBecomeActive(timestamp):
                    self?.appStateModel.saveEvent(.active, at: timestamp)

                case let .didEnterBackground(timestamp):
                    self?.appStateModel.saveEvent(.background, at: timestamp)

                case let .willEnterForeground(timestamp):
                    self?.appStateModel.saveEvent(.foreground, at: timestamp)

                case let .willResignActive(timestamp):
                    self?.appStateModel.saveEvent(.inactive, at: timestamp)

                case let .willTerminate(timestamp):
                    self?.appStateModel.saveEvent(.terminate, at: timestamp)

                case .didFinishLaunching:
                    break
                }
            }
        }
        else {
            hookToAppLifecycle()
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

                self?.appStateModel.saveEvent(.active)
            }

            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                self?.appStateModel.saveEvent(.background)
            }

            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                self?.appStateModel.saveEvent(.foreground)
            }

            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                self?.appStateModel.saveEvent(.inactive)
            }

            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                self?.appStateModel.saveEvent(.terminate)
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
