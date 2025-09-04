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

/// The recording mask class defines an overlay that masks
/// a specified screen part to protect it from unwanted recording.
///
/// It is primarily designed for situations where it is not possible
/// or convenient to use the standard methods for sensitivity settings.
///
/// Individual mask elements will be added to the final record by their
/// index from lowest to highest. An erasing mask can partially cut places
/// covered by a covering mask and vice versa.
@objc(SPLKRecordingMask) @objcMembers
public final class RecordingMaskObjC: NSObject {

    // MARK: - Elements

    /// A list of individual areas to cover or erase.
    public let elements: [MaskElementObjC]


    // MARK: - Initialization

    /// Creates a new recording mask instance with prepared mask elements.
    ///
    /// - Parameter elements: A list of individual areas to cover or erase.
    public init(elements: [MaskElementObjC] = []) {
        self.elements = elements
    }
}


extension RecordingMaskObjC {

    // MARK: - Computed properties

    var recordingMask: RecordingMask {
        RecordingMask(elements: elements.map { element in
            element.maskElement
        })
    }

    // MARK: - Conversion init

    convenience init?(with recordingMask: RecordingMask?) {
        guard let recordingMask else {
            return nil
        }

        let elements = recordingMask.elements.map { element in
            MaskElementObjC(with: element)
        }

        self.init(elements: elements)
    }
}
