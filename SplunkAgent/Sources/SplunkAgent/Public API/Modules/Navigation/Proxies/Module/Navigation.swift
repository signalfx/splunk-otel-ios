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

internal import SplunkNavigation

/// The class implementing Navigation public API.
final class Navigation: NavigationModule {

    // MARK: - Internal

    unowned let module: SplunkNavigation.Navigation


    // MARK: - Preferences

    var preferences: any NavigationModulePreferences

    @discardableResult
    func preferences(_ preferences: any NavigationModulePreferences) -> any NavigationModule {
        self.preferences = preferences

        return self
    }


    // MARK: - State

    let state: any NavigationModuleState


    // MARK: - Initialization

    init(for module: SplunkNavigation.Navigation) {
        self.module = module

        state = NavigationState(for: module)
        preferences = NavigationPreferences(for: module)
    }
}
