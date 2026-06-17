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

/// The screen state to restore when a UINavigationController-presented modal is dismissed.
///
/// A plain `NavigationScreenState?` cannot be stored in the model's dictionary without
/// introducing a box type, because Swift dictionaries cannot distinguish between a key
/// that is absent and a key whose value is `nil`. Using a dedicated enum avoids that
/// ambiguity and makes the two dismissal paths explicit at the call site.
enum RestorationState {
    /// A real screen was showing before the modal was presented; restore to it on dismissal.
    case screen(NavigationScreenState)
    /// No screen had been tracked yet when the modal was presented; reset to nil on dismissal
    /// so subsequent `last.screen.name` values are not polluted by the dismissed modal.
    case noScreen
}

/// Model actor for data used in Navigation module.
actor NavigationModel {

    // MARK: - Public

    private(set) var moduleEnabled: Bool = true
    private(set) var navigations: [ObjectIdentifier: NavigationPair] = [:]
    private(set) var pendingNavigationTargets: [ObjectIdentifier: ObjectIdentifier] = [:]
    private(set) var managedNavigationControllerTargets: Set<ObjectIdentifier> = []
    private(set) var pendingPresentationRestorations: [ObjectIdentifier: RestorationState] = [:]
    private(set) var navigationEventProcessor: any NavigationEventProcessor


    // MARK: - Initialization

    init(navigationEventProcessor: any NavigationEventProcessor = DefaultNavigationEventProcessor()) {
        self.navigationEventProcessor = navigationEventProcessor
    }


    // MARK: - Module management

    func update(moduleEnabled: Bool) {
        self.moduleEnabled = moduleEnabled
    }

    func update(navigationEventProcessor: any NavigationEventProcessor) {
        self.navigationEventProcessor = navigationEventProcessor
    }


    // MARK: - Navigations management

    func navigation(for identifier: ObjectIdentifier) -> NavigationPair? {
        navigations[identifier]
    }

    func update(navigation: NavigationPair, for identifier: ObjectIdentifier) {
        navigations[identifier] = navigation
    }

    func removeNavigation(for identifier: ObjectIdentifier) {
        navigations[identifier] = nil
    }


    // MARK: - Pending navigation targets

    func pendingNavigationTarget(for identifier: ObjectIdentifier) -> ObjectIdentifier? {
        pendingNavigationTargets[identifier]
    }

    func update(pendingNavigationTarget: ObjectIdentifier, for identifier: ObjectIdentifier) {
        pendingNavigationTargets[identifier] = pendingNavigationTarget
    }

    func removePendingNavigationTarget(for identifier: ObjectIdentifier) {
        pendingNavigationTargets[identifier] = nil
    }


    // MARK: - Managed navigation controller targets

    func addManagedNavigationControllerTarget(_ identifier: ObjectIdentifier) {
        managedNavigationControllerTargets.insert(identifier)
    }

    func removeManagedNavigationControllerTarget(_ identifier: ObjectIdentifier) {
        managedNavigationControllerTargets.remove(identifier)
    }

    func isManagedNavigationControllerTarget(_ identifier: ObjectIdentifier) -> Bool {
        managedNavigationControllerTargets.contains(identifier)
    }


    // MARK: - Presentation restorations

    func pendingPresentationRestoration(for identifier: ObjectIdentifier) -> RestorationState? {
        pendingPresentationRestorations[identifier]
    }

    func update(pendingPresentationRestoration: RestorationState, for identifier: ObjectIdentifier) {
        pendingPresentationRestorations[identifier] = pendingPresentationRestoration
    }

    func removePendingPresentationRestoration(for identifier: ObjectIdentifier) {
        pendingPresentationRestorations[identifier] = nil
    }
}
