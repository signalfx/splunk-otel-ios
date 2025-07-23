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

/// The preferences object allows the user to set navigation instrumentation's preferred settings.
///
/// These preferred settings may not represent the actual state,
/// which can be checked with the ``NavigationState`` object.
///
/// To find out the current state, use the information from the ``NavigationState`` object.
///
/// - Note: If you want to set up a parameter, you can change the appropriate property
///         or use the proper method. Both approaches are comparable and give the same result.
public final class NavigationPreferences: NavigationModulePreferences, Codable {

    // MARK: - Internal

    unowned var module: SplunkNavigation.Navigation?


    // MARK: - Initialization

    required init() {
        module = nil
    }

    init(for module: SplunkNavigation.Navigation?) {
        self.module = module

        enableAutomatedTracking = module?.preferences.enableAutomatedTracking
    }


    // MARK: - Automated tracking

    public var enableAutomatedTracking: Bool? {
        didSet {
            module?.preferences.enableAutomatedTracking = enableAutomatedTracking
        }
    }

    @discardableResult public func enableAutomatedTracking(_ enable: Bool?) -> any NavigationModulePreferences {
        enableAutomatedTracking = enable

        return self
    }
}


public extension NavigationPreferences {

    // MARK: - Convenience init

    /// Initializes new preferences object with preconfigured values.
    ///
    /// - Parameter enableAutomatedTracking: If `true`, the ``NavigationModule`` will automatically detect navigation.
    convenience init(enableAutomatedTracking: Bool?) {
        self.init()

        self.enableAutomatedTracking = enableAutomatedTracking
    }
}


extension NavigationPreferences {

    // MARK: - Codable

    // Private preferences are excluded from serialization.
    enum CodingKeys: String, CodingKey {
        case enableAutomatedTracking
    }
}
