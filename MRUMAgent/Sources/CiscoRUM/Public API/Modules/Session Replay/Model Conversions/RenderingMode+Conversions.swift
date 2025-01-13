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

typealias MRUMSessionReplayRenderingMode = CiscoSessionReplay.RenderingMode

// Internal extension to convert `RenderingMode` proxy model to the underlying SessionReplay's `RenderingMode` model
extension RenderingMode {

    // MARK: - Computed properties

    var srRenderingMode: MRUMSessionReplayRenderingMode {

        switch self {
        case .native:
            return .native

        case .wireframe:
            return .wireframe

        case .noRendering:
            return .noRendering
        }
    }


    // MARK: - Conversion init

    init(with renderingMode: MRUMSessionReplayRenderingMode?) {

        switch renderingMode {
        case .native:
            self = .native

        case .wireframe:
            self = .wireframe

        case .noRendering:
            self = .noRendering

        default:
            self = .default
        }
    }
}
