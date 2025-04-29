//
/*
Copyright 2024 Splunk Inc.

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

internal import CiscoSessionReplay
import UIKit

/// The sensitivity object implements public API for the view element's sensitivity.
final class SessionReplayCustomId: SessionReplayModuleCustomId {

    // MARK: - Internal

    private(set) unowned var module: CiscoSessionReplay.SessionReplay


    // MARK: - Initialization

    init(for module: CiscoSessionReplay.SessionReplay) {
        self.module = module
    }


    // MARK: - View sensitivity

    public subscript(view: UIView) -> String? {
        get {
            view.customId
        }
        set {
            view.customId = newValue
        }
    }

    @discardableResult public func set(_ view: UIView, _ customId: String?) -> SessionReplayModuleCustomId {
        self[view] = customId

        return self
    }
}
