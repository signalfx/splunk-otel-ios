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

typealias SplunkSessionReplayInteractionCapture = CiscoSessionReplay.InteractionCapture

/// Internal extensions to convert between the proxy and Session Replay interaction capture models.
extension SplunkSessionReplayInteractionCapture {

    // MARK: - Conversion initialization

    convenience init(from interactionCapture: any SessionReplayModuleInteractionCapture) {
        self.init()

        isKeyboardEnabled = interactionCapture.isKeyboardEnabled
        isTouchEnabled = interactionCapture.isTouchEnabled
        isGestureEnabled = interactionCapture.isGestureEnabled
        isFocusEnabled = interactionCapture.isFocusEnabled
        isRageTapEnabled = interactionCapture.isRageTapEnabled
    }
}


extension SessionReplayInteractionCapture {

    // MARK: - Conversion initialization

    convenience init(from interactionCapture: SplunkSessionReplayInteractionCapture) {
        self.init()

        isKeyboardEnabled = interactionCapture.isKeyboardEnabled
        isTouchEnabled = interactionCapture.isTouchEnabled
        isGestureEnabled = interactionCapture.isGestureEnabled
        isFocusEnabled = interactionCapture.isFocusEnabled
        isRageTapEnabled = interactionCapture.isRageTapEnabled
    }
}
