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

/// A standard recurring job that also takes into account the application lifecycle.
///
/// When the application moves to the background, it fires the execution block only once more
/// and does the same when it returns to the foreground. After returning to the foreground,
/// it executes according to the specified interval.
///
/// - Important: While the application is in the background, it does not execute the block
///             and waits for the transition to the foreground.
class LifecycleRepeatingJob: RepeatingJob {

    // MARK: - Private

    private var suspendedByLifecycle: Bool = false


    // MARK: - Initialization

    required init(named: String? = nil, interval: TimeInterval, block: @escaping () -> Void) {
        super.init(named: named, interval: interval, block: block)

        // Monitoring for application lifecycle
        hookToAppLifecycle()
    }


    // MARK: - Job management

    /// Starts the job execution (if it has not been interrupted by the application going into the background).
    ///
    /// The first execution of the specified block is fired at the earliest after the `interval`.
    ///
    /// - Returns: The actual job instance.
    @discardableResult
    override func resume() -> Self {
        guard !suspendedByLifecycle else {
            return self
        }

        super.resume()

        return self
    }

    /// Stops the job execution immediately (if not yet, unless interrupted
    /// by the application going into the background).
    ///
    /// - Returns: The actual job instance.
    @discardableResult
    override func suspend() -> Self {
        guard !suspendedByLifecycle else {
            return self
        }

        super.suspend()

        return self
    }


    // MARK: - Application lifecycle

    private func hookToAppLifecycle() {
        #if os(iOS) || os(tvOS) || os(visionOS)

            // Transitioning an application to the background
            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                guard
                    let suspended = self?.suspended,
                    suspended == false
                else {
                    return
                }

                // We need to stop job after this transition ...
                self?.suspend()
                self?.suspendedByLifecycle = true

                // ... and make one transition run
                self?.executionBlock()
            }

            // Transitioning an application to the foreground
            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                guard
                    let suspendedByLifecycle = self?.suspendedByLifecycle,
                    suspendedByLifecycle == true
                else {
                    return
                }

                // We need to resume job ...
                self?.suspendedByLifecycle = false
                self?.resume()

                // ... and make one transition run
                self?.executionBlock()
            }

        #endif
    }
}
