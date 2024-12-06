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

/// The class implements a description of support for the current platform.
class PlatformSupport: PlatformSupporting {

    // MARK: - Static properties

    static var current: any PlatformSupporting = PlatformSupport()


    // MARK: - Platform support

    var scope: PlatformSupportScope {
        switch CompileInfo.platform {
        case .macOS:
            return .unsupported

        case .macCatalyst:
            return .compileOnly

        case .iOS:
            return iOSSupportScope()

        case .watchOS:
            return .unsupported

        case .tvOS:
            return .compileOnly

        case .visionOS:
            return .compileOnly

        default:
            return .unsupported
        }
    }


    // MARK: - Designed for iPad

    let isiOSAppOnMac = iOSAppOnMacDevice()

    let isiOSAppOnVision = iOSAppOnVisionDevice()


    // MARK: - Initialization

    private init() {}


    // MARK: - Platform support helpers

    private func iOSSupportScope() -> PlatformSupportScope {
        guard !isiOSAppOnMac else {
            return .compileOnly
        }

        guard !isiOSAppOnVision else {
            return .compileOnly
        }

        return .full
    }


    // MARK: - Designed for iPad helpers

    private static func iOSAppOnMacDevice() -> Bool {
        if #available(iOS 14, tvOS 14, macOS 11, visionOS 1, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }

        return false
    }

    private static func iOSAppOnVisionDevice() -> Bool {
        // On visionOS, an adequate method for detecting an app running in
        // `Apple Vision (Designed for iPad)` mode is not yet available.
        //
        // This method serves as a fallback until Apple adds an appropriate solution.
        NSClassFromString("UIWindowSceneGeometryPreferencesVision") != nil
    }
}
