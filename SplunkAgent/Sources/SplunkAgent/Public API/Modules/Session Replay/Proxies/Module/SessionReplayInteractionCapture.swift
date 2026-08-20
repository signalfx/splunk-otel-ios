//
/*
Copyright 2026 Splunk Inc.

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

/// The interaction capture object implements public API for interaction category controls.
final class SessionReplayInteractionCapture: SessionReplayModuleInteractionCapture {

    // MARK: - Private

    unowned var module: CiscoSessionReplay.SessionReplay?

    private let detachedCapture = CiscoSessionReplay.InteractionCapture()

    private var capture: CiscoSessionReplay.InteractionCapture {
        module?.preferences.interactionCapture ?? detachedCapture
    }


    // MARK: - Categories

    var isKeyboardEnabled: Bool {
        get {
            capture.isKeyboardEnabled
        }
        set {
            capture.isKeyboardEnabled = newValue
        }
    }

    var isTouchEnabled: Bool {
        get {
            capture.isTouchEnabled
        }
        set {
            capture.isTouchEnabled = newValue
        }
    }

    var isGestureEnabled: Bool {
        get {
            capture.isGestureEnabled
        }
        set {
            capture.isGestureEnabled = newValue
        }
    }

    var isFocusEnabled: Bool {
        get {
            capture.isFocusEnabled
        }
        set {
            capture.isFocusEnabled = newValue
        }
    }

    var isRageTapEnabled: Bool {
        get {
            capture.isRageTapEnabled
        }
        set {
            capture.isRageTapEnabled = newValue
        }
    }


    // MARK: - Initialization

    init(for module: CiscoSessionReplay.SessionReplay? = nil) {
        self.module = module
    }


    // MARK: - Bulk updates

    func enableAll() {
        capture.enableAll()
    }

    func disableAll() {
        capture.disableAll()
    }
}
