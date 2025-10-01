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

/// The mask element class defines one area and its role in the recording mask.
@objc(SPLKMaskElement)
@objcMembers
public final class MaskElementObjC: NSObject {

    // MARK: - Public

    /// A rectangle that bounds the masked area.
    public let rect: CGRect

    /// A type of mask element.
    public let type: MaskTypeObjC


    // MARK: - Initialization

    /// Creates a new mask element with prepared preconfigured values.
    ///
    /// - Parameters:
    ///   - rect: A rectangle that bounds the masked area.
    ///   - maskElementType: A type of mask element.
    public init(rect: CGRect, maskElementType: MaskTypeObjC = .covering) {
        self.rect = rect
        type = maskElementType
    }
}


extension MaskElementObjC {

    // MARK: - Computed properties

    var maskElement: MaskElement {
        MaskElement(rect: rect, type: type.maskType)
    }


    // MARK: - Conversion init

    convenience init(with maskElement: MaskElement) {
        self.init(
            rect: maskElement.rect,
            maskElementType: MaskTypeObjC(with: maskElement.type)
        )
    }
}
