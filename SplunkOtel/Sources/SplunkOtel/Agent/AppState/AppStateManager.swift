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

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#endif

class AppStateManager: AgentAppStateManager {

    // MARK: - Internal properties

    private var appStateModel: AppStateModel

    // Serializes external access to stored data
    private let accessQueue: DispatchQueue

    // MARK: - Initialization

    init(appStateModel: AppStateModel = AppStateModel()) {
        self.appStateModel = appStateModel

        let queueName = PackageIdentifier.default(named: "appStateAccess")
        accessQueue = DispatchQueue(label: queueName)

        hookToAppLifecycle()
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
