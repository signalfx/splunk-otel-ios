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

/// The preferences object is a representation of the module user's preferred settings.
///
/// These are the settings that the user would like the module to use. The entered values
/// always represent only the preferred settings, and the resulting state
/// in which the module works may be different for each property.
///
/// To find out the current state, use the information from the ``RuntimeState`` object.
public final class Preferences: Codable, Sendable {

    // MARK: - Internal

    nonisolated(unsafe) unowned var module: Navigation?


    // MARK: - Automated tracking

    /// A `Boolean` value determines whether the module should automatically detect navigation in the application.
    ///
    /// The default value is `nil` (no preferred mode). However, this detection is disabled by default, see ``RuntimeState``.
    nonisolated(unsafe) public var enableAutomatedTracking: Bool? {
        didSet {
            module?.update()
        }
    }

    /// Sets whether or not the module should automatically detect navigation in the application.
    ///
    /// - Parameter enable: If `true`, the module will automatically detect navigation.
    ///
    /// - Returns: The updated preferences object.
    @discardableResult
    public func enableAutomatedTracking(_ enable: Bool?) -> Preferences {
        enableAutomatedTracking = enable

        return self
    }
}


extension Preferences {

    // MARK: - Convenience init

    /// Initializes new preferences object with preconfigured values.
    ///
    /// - Parameter enableAutomatedTracking: If `true`, the module will automatically detect navigation.
    public convenience init(
        enableAutomatedTracking: Bool? = nil
    ) {
        self.init()

        self.enableAutomatedTracking = enableAutomatedTracking
    }
}


extension Preferences {

    // MARK: - Internal convenience init

    convenience init(for module: Navigation) {
        self.init()

        self.module = module
        module.update()
    }
}


extension Preferences {

    // MARK: - Codable

    /// Private variables are excluded from serialization.
    enum CodingKeys: String, CodingKey {
        case enableAutomatedTracking
    }
}
