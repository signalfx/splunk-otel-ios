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

internal import CiscoSwizzling
import Foundation

/// Provides navigation action events produced by swizzling.
protocol NavigationEventStreamProviding: Sendable {
    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent>
}

/// Default stream provider backed by CiscoSwizzling.
struct DefaultNavigationEventStreamProvider: NavigationEventStreamProviding, Sendable {
    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        try await DefaultSwizzling.navigation
    }
}

/// Abstracts notification source used by legacy detection.
protocol NotificationEventsProviding: Sendable {
    func notifications(for name: Notification.Name) -> AsyncStream<Notification>
}

/// Default notification provider backed by NotificationCenter.
struct DefaultNotificationEventsProvider: NotificationEventsProviding, Sendable {
    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func notifications(for name: Notification.Name) -> AsyncStream<Notification> {
        notificationCenter.notifications(for: name)
    }
}

/// Navigation detection mode used by the module.
enum NavigationDetectionMode {
    case legacy
    case modern
}
