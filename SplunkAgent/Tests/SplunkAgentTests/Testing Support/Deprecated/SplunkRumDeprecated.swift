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

@testable import SplunkAgent

/// The protocol is used to hide and suppress warnings related
/// to deprecated API calls on the `SplunkRum` class.
///
/// We must use this workaround since we still need to test these
/// deprecated APIs, and Swift does not provide a direct solution.
public protocol SplunkRumDeprecated {

    // MARK: - Screen name

    static func setScreenName(_ name: String)
    static func addScreenNameChangeCallback(_ callback: ((String) -> Void)?)
}


extension SplunkRum: SplunkRumDeprecated {

    // MARK: - Screen name

    static func deprecatedSetScreenName(_ name: String) {
        (Self.self as SplunkRumDeprecated.Type).setScreenName(name)
    }

    static func deprecatedAddScreenNameChangeCallback(_ callback: ((String) -> Void)?) {
        (Self.self as SplunkRumDeprecated.Type).addScreenNameChangeCallback(callback)
    }
}
