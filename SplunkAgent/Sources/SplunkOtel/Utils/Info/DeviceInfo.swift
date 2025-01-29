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

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit

#elseif os(macOS)
    import Darwin
#endif

/// Provides information about a device.
struct DeviceInfo {

    // MARK: - Basic information

    static var type: String? {
        var deviceType: String?

        #if os(iOS) || os(tvOS) || os(visionOS)
            var systemInfo = utsname()
            uname(&systemInfo)

            deviceType = withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) { pointer in
                    String(validatingUTF8: pointer)
                }
            }

        #elseif os(macOS)
            deviceType = sysctlParam(path: "hw.model")
        #endif

        return deviceType
    }

    static var platform: String {
        #if os(iOS) || os(tvOS) || os(visionOS)
            return UIDevice.current.model

        #elseif os(macOS)
            return "Mac"
        #endif
    }

    static var architecture: String? {
        var architectureString = "Unknown"

        #if os(iOS) || os(tvOS) || os(visionOS)
            var size: size_t = 0
            var cpuType: cpu_type_t = 0

            size = cpuType.bitWidth
            sysctlbyname("hw.cputype", &cpuType, &size, nil, 0)

            // Values for cputype and cpusubtype defined in mach/machine.h
            if cpuType == CPU_TYPE_X86_64 {
                architectureString = "x86_64"

            } else if cpuType == CPU_TYPE_I386 {
                architectureString = "i386 (Simulator)"

            } else if cpuType == CPU_TYPE_ARM64 {
                architectureString = "ARM64"

            } else if cpuType == CPU_TYPE_ARM {
                architectureString = "ARM"
            }

        #elseif os(macOS)
            architectureString = sysctlParam(path: "hw.machine")
        #endif

        return architectureString
    }

    static var deviceID: String? {
        #if os(iOS) || os(tvOS) || os(visionOS)
            return UIDevice.current.identifierForVendor?.uuidString
        #elseif os(macOS)
            return nil
        #endif
    }


    // MARK: - Private methods

    // Prepared for potential use on macOS (or in Catalyst Apps)
    // periphery:ignore
    @available(macOS 10.13, *)
    private static func sysctlParam(path: String) -> String {
        var size = 0
        sysctlbyname(path, nil, &size, nil, 0)

        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname(path, &machine, &size, nil, 0)

        return String(cString: machine)
    }
}
