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

/// Defines a basic set of properties describing the target platform's code support.
protocol PlatformSupporting {

    // MARK: - Static properties

    /// Information about the current platform on which the application is currently running.
    static var current: any PlatformSupporting { get }


    // MARK: - Platform support

    /// Scope of support for the target platform.
    var scope: PlatformSupportScope { get }


    // MARK: - Designed for iPad

    /// A Boolean value that indicates whether the process
    /// is an iPhone or iPad app running on a **Mac** device.
    var isiOSAppOnMac: Bool { get }

    /// A Boolean value that indicates whether the process
    /// is an iPhone or iPad app running on a **Vision** device.
    var isiOSAppOnVision: Bool { get }
}
