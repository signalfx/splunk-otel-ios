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

import CoreGraphics
import Foundation

/// The mask element structure defines one area and its role in the recording mask.
public struct MaskElement: Codable, Equatable {

    // MARK: - Inline types

    /// A type of mask element.
    public enum MaskType: Int, Codable {

        /// Covers area that will not be recorded.
        ///
        /// Covering masks can be partially erased if at least
        /// partially covered by erasing masks on higher layers.
        case covering

        /// Erases the lower layers of the mask.
        case erasing
    }


    // MARK: - Public

    /// A rectangle that bounds the masked area.
    public let rect: CGRect

    /// A type of mask element.
    public let type: MaskType


    // MARK: - Initialization

    /// Creates a new mask element structure with prepared preconfigured values.
    ///
    /// - Parameters:
    ///   - rect: A rectangle that bounds the masked area.
    ///   - type: A type of mask element.
    ///
    ///   - Returns: A newly created `MaskElement` structure.
    public init(rect: CGRect, type: MaskType = .covering) {
        self.rect = rect
        self.type = type
    }
}


/// The recording mask structure defines an overlay that masks
/// a specified screen part to protect it from unwanted recording.
///
/// It is primarily designed for situations where it is not possible
/// or convenient to use the standard methods for sensitivity settings.
///
/// Individual mask elements will be added to the final record by their
/// index from lowest to highest. An erasing mask can partially cut places
/// covered by a covering mask and vice versa.
public struct RecordingMask: Codable, Equatable {

    // MARK: - Elements

    /// A list of individual areas to cover or erase.
    public var elements: [MaskElement]


    // MARK: - Initialization

    /// Creates a new recording mask structure with prepared mask elements.
    ///
    /// - Parameter elements: A list of individual areas to cover or erase.
    ///
    /// - Returns: A newly created `RecordingMask` structure.
    public init(elements: [MaskElement] = []) {
        self.elements = elements
    }
}
