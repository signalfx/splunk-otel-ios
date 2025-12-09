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

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#endif

extension DefaultSession {

    // MARK: - Application lifecycle

    func hookToAppLifecycle() {
        #if os(iOS) || os(tvOS) || os(visionOS)

            // Transitioning an application to the background
            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                // We need to mark the time of this transition
                self?.enterBackground = Date()
            }

            // Transitioning an application to the foreground
            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                // Refresh a session and then clear the `enterBackground` timestamp
                if self?.enterBackground != nil {
                    self?.refreshSession()
                    self?.enterBackground = nil
                }
            }

            // The application is being terminated
            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                // We need to end current session
                self?.endSession()
            }

        #endif
    }
}
