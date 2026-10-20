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

import Foundation
import SplunkAgent

/// The interaction capture object controls which detected interaction categories are captured.
@objc(SPLKSessionReplayModuleInteractionCapture)
// swiftlint:disable:next type_name
public final class SessionReplayModuleInteractionCaptureObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC

    private var capture: any SessionReplayModuleInteractionCapture {
        owner.agent.sessionReplay.preferences.interactionCapture
    }


    // MARK: - Categories

    /// Indicates whether soft keyboard interactions are captured.
    @objc(keyboardEnabled)
    public var keyboardEnabled: Bool {
        @objc(isKeyboardEnabled)
        get {
            capture.isKeyboardEnabled
        }
        @objc(setKeyboardEnabled:)
        set {
            capture.isKeyboardEnabled = newValue
        }
    }

    /// Indicates whether pointer and touch interactions are captured.
    @objc(touchEnabled)
    public var touchEnabled: Bool {
        @objc(isTouchEnabled)
        get {
            capture.isTouchEnabled
        }
        @objc(setTouchEnabled:)
        set {
            capture.isTouchEnabled = newValue
        }
    }

    /// Indicates whether recognized gesture interactions are captured.
    ///
    /// Rage tap interactions are controlled separately by ``rageTapEnabled``.
    @objc(gestureEnabled)
    public var gestureEnabled: Bool {
        @objc(isGestureEnabled)
        get {
            capture.isGestureEnabled
        }
        @objc(setGestureEnabled:)
        set {
            capture.isGestureEnabled = newValue
        }
    }

    /// Indicates whether focus-change interactions are captured.
    @objc(focusEnabled)
    public var focusEnabled: Bool {
        @objc(isFocusEnabled)
        get {
            capture.isFocusEnabled
        }
        @objc(setFocusEnabled:)
        set {
            capture.isFocusEnabled = newValue
        }
    }

    /// Indicates whether rage tap interactions are captured.
    @objc(rageTapEnabled)
    public var rageTapEnabled: Bool {
        @objc(isRageTapEnabled)
        get {
            capture.isRageTapEnabled
        }
        @objc(setRageTapEnabled:)
        set {
            capture.isRageTapEnabled = newValue
        }
    }


    // MARK: - Category control

    /// Enables capture for every configurable interaction category.
    @objc(enableAll)
    public func enableAll() {
        capture.enableAll()
    }

    /// Disables capture for every configurable interaction category.
    @objc(disableAll)
    public func disableAll() {
        capture.disableAll()
    }


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
