//
/*
Copyright 2026 Splunk Inc.

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

extension DefaultEventManager {

    // MARK: - Lifecycle trace flushing

    func startTraceLifecycleFlush() {
        removeTraceLifecycleObservers()

        #if os(iOS) || os(tvOS) || os(visionOS)
            addTraceLifecycleObserver(
                UIApplication.didEnterBackgroundNotification,
                waitForPersistence: false
            )
            addTraceLifecycleObserver(
                UIApplication.willTerminateNotification,
                waitForPersistence: true
            )
        #endif
    }

    func removeTraceLifecycleObservers() {
        for observer in traceLifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        traceLifecycleObservers.removeAll()
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
        private func addTraceLifecycleObserver(
            _ name: Notification.Name,
            waitForPersistence: Bool
        ) {
            let observer = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                guard let self else {
                    return
                }

                let flush: () -> Void = { [weak self] in
                    self?.concreteTraceProcessor.forceFlush()
                }

                if waitForPersistence {
                    if DispatchQueue.getSpecific(key: traceLifecycleFlushQueueKey) != nil {
                        flush()
                    }
                    else {
                        traceLifecycleFlushQueue.sync(execute: flush)
                    }
                }
                else {
                    traceLifecycleFlushQueue.async(execute: flush)
                }
            }
            traceLifecycleObservers.append(observer)
        }
    #endif
}
