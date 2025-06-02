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

/// Model actor for data used in Navigation module.
actor NavigationModel {

    // MARK: - Public

    public private(set) var moduleEnabled: Bool = true


    public private(set) var screenName: String = "unknown"

    public private(set) var isManualScreenName = false


    public private(set) var navigations: [ObjectIdentifier: NavigationPair] = [:]

    public private(set) var agentVersion: String?


    // MARK: - Module management

    func update(moduleEnabled: Bool) {
        self.moduleEnabled = moduleEnabled
    }


    // MARK: - Screen name management

    func update(screenName: String) {
        self.screenName = screenName
    }

    func update(isManualScreenName: Bool) {
        self.isManualScreenName = isManualScreenName
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


    // MARK: - Agent version management

    func update(agentVersion: String?) {
        self.agentVersion = agentVersion
    }
}
