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

import Foundation
import SplunkAgent

/// A video rendering mode for captured data.
@objc(SPLKRenderingMode)
public final class RenderingModeObjC: NSObject {

    // MARK: - Rendering modes

    /// Render the video as the screen images and also
    /// as a wireframe representation of screen data.
    @objc
    public static let native = NSNumber(value: 0)

    /// Render the video only as a wireframe representation of screen data.
    @objc
    public static let wireframeOnly = NSNumber(value: 1)


    // MARK: - Initialization

    // Initialization is hidden from the public API
    // as we only need to work with the class type.
    override init() {}


    // MARK: - Conversion utils

    static func renderingMode(for value: NSNumber) -> RenderingMode {
        switch value {
        case native:
            return .native

        case wireframeOnly:
            return .wireframeOnly

        default:
            return .default
        }
    }

    static func value(for renderingMode: RenderingMode) -> NSNumber {
        switch renderingMode {
        case .native:
            return native

        case .wireframeOnly:
            return wireframeOnly
        }
    }
}


@objc
public extension RenderingModeObjC {

    // MARK: - Default preset

    /// Default video rendering mode.
    @objc(defaultRenderingMode)
    static let `default` = value(for: RenderingMode.default)
}
