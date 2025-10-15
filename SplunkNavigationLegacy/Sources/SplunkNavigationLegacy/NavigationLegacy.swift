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

internal import CiscoLogger
internal import CiscoSwizzling
import Foundation
import SplunkCommon
import UIKit

public final class NavigationLegacy {

    // MARK: - Initialization

    /// Module protocol conformance.
    public required init() {
        // Prepare a stream for screen name changes
        initalizeUIInstrumentation()

        // Maps the legacy "screenNameSpans" property (= automatic navigation?)
        screenNameSpansEnabled = true

        // Maps the legacy "showVCInstrumentation" property (= ?)
        showVCInstrumentation = true
    }

    public func setManualScreenName(_ screenName: String) {
        internal_setScreenName(screenName, true)
    }

    public func legacyScreenName() -> String {
        return screenName
    }
}
