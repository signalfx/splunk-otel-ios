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

import Foundation
@_implementationOnly import CiscoSessionReplay

// MARK: - SplunkSessionReplay RecordingMask-related type conversions

typealias SplunkSessionReplayRecordingMask = CiscoSessionReplay.RecordingMask
typealias SplunkSessionReplayMaskElement = CiscoSessionReplay.MaskElement
typealias SplunkSessionReplayMaskType = CiscoSessionReplay.MaskElement.MaskType

extension SplunkSessionReplayMaskType {

    // MARK: - MaskType conversion initialization

    init(from maskType: MaskElement.MaskType) {

        switch maskType {
        case .erasing:
            self = .erasing

        case .covering:
            self = .covering
        }
    }
}

extension SplunkSessionReplayMaskElement {

    // MARK: - MaskElement conversion initialization

    init(from maskElement: MaskElement) {
        let rect = maskElement.rect
        let type = SplunkSessionReplayMaskType(from: maskElement.type)

        self.init(rect: rect, type: type)
    }
}

extension SplunkSessionReplayRecordingMask {

    // MARK: - RecordingMasks conversion

    init?(from recordingMask: RecordingMask?) {
        guard
            let recordingMask = recordingMask,
            !recordingMask.elements.isEmpty
        else {
            return nil
        }

        // Converts all contained elements
        let elements = recordingMask.elements.map { maskElement in
            SplunkSessionReplayMaskElement(from: maskElement)
        }

        self.init(elements: elements)
    }
}

extension MaskElement.MaskType {

    // MARK: - MaskType initialization

    init(from maskType: SplunkSessionReplayMaskType) {

        switch maskType {
        case .erasing:
            self = .erasing

        case .covering:
            self = .covering
        }
    }
}


// MARK: - SessionReplay proxy RecordingMask-related type conversions

extension MaskElement {

    // MARK: - MaskElement initialization

    init(from maskElement: SplunkSessionReplayMaskElement) {
        rect = maskElement.rect
        type = MaskType(from: maskElement.type)
    }
}


extension RecordingMask {

    // MARK: - RecordingMasks conversion

    init?(from recordingMask: SplunkSessionReplayRecordingMask?) {
        guard
            let recordingMask = recordingMask,
            !recordingMask.elements.isEmpty
        else {
            return nil
        }

        // Converts all contained elements
        elements = recordingMask.elements.map { maskElement in
            MaskElement(from: maskElement)
        }
    }
}
