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

public extension SplunkRum {

    // MARK: - Screen name

    /// Sets a custom screen name.
    ///
    /// This name will be used for all subsequent screen-related spans until a new name is set.
    ///
    /// - Parameter name: The custom screen name.
    @available(
        *,
        deprecated,
        renamed: "SplunkRum.shared.navigation.track(screen:)",
        message: "This method will be removed in a later version."
    )
    static func setScreenName(_ name: String) {
        shared.navigation.track(screen: name)
    }

    /// Registers a callback to observe screen name changes.
    ///
    /// - Parameter callback: A closure that receives the new screen name as a `String`.
    ///                       Pass `nil` to remove a previously registered callback.
    @available(*, deprecated, message: "This method will be removed in a later version.")
    static func addScreenNameChangeCallback(_ callback: ((String) -> Void)?) {
        shared.screenNameChangeCallback = callback
    }
}