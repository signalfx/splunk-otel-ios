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

internal import CiscoSessionReplay
import Foundation

/// The preferences object is a representation of the user's preferred settings.
///
/// These are the settings that the user would like the ``SessionReplayModule`` to use.
/// The entered values always represent only the preferred settings, and the resulting state
/// in which the module works may be different for each property.
///
/// To find out the current state, use the information from the ``SessionReplayModuleState``.
///
/// - Note: If you want to set up a parameter, you can change the appropriate property
///         or use the proper method. Both approaches are comparable and give the same result.
public final class SessionReplayPreferences: SessionReplayModulePreferences {

    // MARK: - Internal

    unowned var module: CiscoSessionReplay.SessionReplay? {
        didSet {
            (interactionCapture as? SessionReplayInteractionCapture)?.module = module
        }
    }

    // MARK: - Interaction capture

    /// Configuration that controls which detected interaction categories are captured.
    ///
    /// All categories are enabled by default. Updating this object affects only
    /// interactions received after the change.
    public private(set) lazy var interactionCapture: any SessionReplayModuleInteractionCapture =
        SessionReplayInteractionCapture(for: module)


    // MARK: - Rendering

    /// The preferred ``RenderingMode`` for the session replay.
    ///
    /// This setting determines how the session replay is visually captured. The actual rendering
    /// mode in use can be confirmed by checking the ``SessionReplayModuleState``.
    public var renderingMode: RenderingMode? {
        didSet {
            module?.preferences.renderingMode = renderingMode?.srRenderingMode
        }
    }

    /// Sets the preferred rendering mode for the session replay.
    ///
    /// This method provides a fluent interface for configuring the rendering mode.
    ///
    /// - Parameter renderingMode: The desired ``RenderingMode``.
    ///
    /// - Returns: The ``SessionReplayModulePreferences`` instance for chaining further configurations.
    @discardableResult
    public func renderingMode(_ renderingMode: RenderingMode?) -> SessionReplayModulePreferences {
        self.renderingMode = renderingMode

        return self
    }


    // MARK: - Initialization

    init(
        for module: CiscoSessionReplay.SessionReplay? = nil,
        interactionCapture: (any SessionReplayModuleInteractionCapture)? = nil
    ) {
        self.module = module
        renderingMode = module?.preferences.renderingMode.map(RenderingMode.init(with:))

        if let interactionCapture {
            self.interactionCapture = interactionCapture
        }
    }
}


extension SessionReplayPreferences: Codable {

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case renderingMode
        case interactionCapture
    }

    private struct InteractionCaptureState: Codable {
        let isKeyboardEnabled: Bool
        let isTouchEnabled: Bool
        let isGestureEnabled: Bool
        let isFocusEnabled: Bool
        let isRageTapEnabled: Bool

        init(_ capture: any SessionReplayModuleInteractionCapture) {
            isKeyboardEnabled = capture.isKeyboardEnabled
            isTouchEnabled = capture.isTouchEnabled
            isGestureEnabled = capture.isGestureEnabled
            isFocusEnabled = capture.isFocusEnabled
            isRageTapEnabled = capture.isRageTapEnabled
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            isKeyboardEnabled = try container.decodeIfPresent(Bool.self, forKey: .isKeyboardEnabled) ?? true
            isTouchEnabled = try container.decodeIfPresent(Bool.self, forKey: .isTouchEnabled) ?? true
            isGestureEnabled = try container.decodeIfPresent(Bool.self, forKey: .isGestureEnabled) ?? true
            isFocusEnabled = try container.decodeIfPresent(Bool.self, forKey: .isFocusEnabled) ?? true
            isRageTapEnabled = try container.decodeIfPresent(Bool.self, forKey: .isRageTapEnabled) ?? true
        }
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init()

        renderingMode = try container.decodeIfPresent(RenderingMode.self, forKey: .renderingMode)

        if let state = try container.decodeIfPresent(InteractionCaptureState.self, forKey: .interactionCapture) {
            interactionCapture.isKeyboardEnabled = state.isKeyboardEnabled
            interactionCapture.isTouchEnabled = state.isTouchEnabled
            interactionCapture.isGestureEnabled = state.isGestureEnabled
            interactionCapture.isFocusEnabled = state.isFocusEnabled
            interactionCapture.isRageTapEnabled = state.isRageTapEnabled
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(renderingMode, forKey: .renderingMode)
        try container.encode(InteractionCaptureState(interactionCapture), forKey: .interactionCapture)
    }
}


extension SessionReplayPreferences {

    // MARK: - Convenience init

    /// Initializes the preferences with a specific rendering mode.
    ///
    /// - Parameter renderingMode: The ``RenderingMode`` to use for the session replay.
    public convenience init(renderingMode: RenderingMode) {
        self.init()

        self.renderingMode = renderingMode
    }
}
