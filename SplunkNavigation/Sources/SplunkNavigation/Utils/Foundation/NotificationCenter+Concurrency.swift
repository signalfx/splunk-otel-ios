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

extension NotificationCenter {
    /// Creates an `AsyncStream` of notifications for a given name, providing backward compatibility for iOS versions prior to 15.
    func notifications(for name: Notification.Name) -> AsyncStream<Notification> {
        guard #available(iOS 15.0, *) else {
            // Provide a fallback for iOS 13/14 using the classic observer pattern.
            return AsyncStream { continuation in
                let observer = self.addObserver(forName: name, object: nil, queue: nil) { notification in
                    continuation.yield(notification)
                }

                continuation.onTermination = { _ in
                    self.removeObserver(observer)
                }
            }
        }

        // Use the modern, efficient API on iOS 15+
        return publisher(for: name).values.eraseToStream()
    }
}

#if canImport(Combine)
    import Combine

    @available(iOS 15.0, *)
    extension AsyncSequence {
        /// Helper to erase the specific async sequence type to a generic AsyncStream.
        func eraseToStream() -> AsyncStream<Element> {
            AsyncStream { continuation in
                let task = Task {
                    do {
                        for try await value in self {
                            continuation.yield(value)
                        }
                        continuation.finish()
                    }
                    catch {
                        continuation.finish()
                    }
                }
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }
    }
#endif
