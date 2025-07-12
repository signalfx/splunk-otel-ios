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

import CoreGraphics
import Foundation

/// A building block for a ``RecordingMask``, defining a rectangular area to be either masked or unmasked.
public struct MaskElement: Codable, Equatable {

    // MARK: - Inline types

    /// The type of a mask element, which determines its behavior.
    public enum MaskType: Int, Codable {

        /// Masks an area, preventing it from being recorded.
        ///
        /// Covering masks can be partially erased by an `.erasing` mask on a higher layer.
        case covering

        /// Unmasks an area, revealing content even if it is covered by a `.covering` mask on a lower layer.
        case erasing
    }


    // MARK: - Public

    /// The rectangular frame of the mask element, in screen coordinates.
    public let rect: CGRect

    /// The type of mask, which determines if the area is covered or erased.
    public let type: MaskType


    // MARK: - Initialization

    /// Initializes a mask element with a specific frame and type.
    ///
    /// - Parameters:
    ///   - rect: The rectangular frame for the mask element.
    ///   - type: The type of mask, either `.covering` or `.erasing`. Defaults to `.covering`.
    public init(rect: CGRect, type: MaskType = .covering) {
        self.rect = rect
        self.type = type
    }
}


/// An overlay composed of one or more ``MaskElement`` instances that masks specified parts of the screen during a Session Replay recording.
///
/// This is primarily designed for situations where it is not possible or convenient to use
/// the standard view-based sensitivity settings.
///
/// Individual mask elements are layered in the order they appear in the `elements` array, from bottom to top.
/// An `.erasing` mask can cut holes in a `.covering` mask on a lower layer, and vice versa.
///
/// ### Example ###
/// ```
/// // Create a mask that covers the whole screen except for a small window
/// let screenBounds = UIScreen.main.bounds
///
/// let fullScreenCover = MaskElement(rect: screenBounds, type: .covering)
/// let revealWindow = MaskElement(rect: CGRect(x: 50, y: 50, width: 100, height: 100), type: .erasing)
///
/// let recordingMask = RecordingMask(elements: [fullScreenCover, revealWindow])
/// SplunkRum.shared.sessionReplay.recordingMask = recordingMask
/// ```
public struct RecordingMask: Codable, Equatable {

    // MARK: - Elements

    /// An array of ``MaskElement`` instances that define the mask, ordered from bottom to top.
    public var elements: [MaskElement]


    // MARK: - Initialization

    /// Initializes a recording mask with an array of mask elements.
    ///
    /// - Parameter elements: An array of ``MaskElement`` instances. Defaults to an empty array.
    public init(elements: [MaskElement] = []) {
        self.elements = elements
    }
}