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

/// The state object implements public API for the current state of the Navigation module.
public final class NavigationState: NavigationModuleState {

    // MARK: - Internal

    unowned var module: SplunkNavigation.Navigation?


    // MARK: - Initialization

    init(for module: SplunkNavigation.Navigation?) {
        self.module = module
    }


    // MARK: - Automated tracking

    public var isAutomatedTrackingEnabled: Bool {
        module?.state.isAutomatedTrackingEnabled ?? false
    }
}
