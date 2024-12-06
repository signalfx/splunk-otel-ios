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

/// Agent resources represent immutable information about the Agent, the application,
/// an operating system and a device. This information is used for decorating Events.
public protocol AgentResources {

    // MARK: - App info

    /// Application identifier (e.g. bundle id), or customer supplied app identifier.
    var appName: String { get }

    /// Application version.
    var appVersion: String { get }

    /// Application build number.
    var appBuild: String { get }


    // MARK: - Agent info

    /// Optional Agent hybrid type, e.g. `react-native`.
    var agentHybridType: String? { get }

    /// Agent version.
    var agentVersion: String { get }


    // MARK: - Device info

    /// Device model identifier, e.g. `iPhone3,4`.
    var deviceModelIdentifier: String { get }

    /// Device manufacturer, e.g. `Apple`.
    var deviceManufacturer: String { get }

    /// Device identifier.
    var deviceID: String { get }


    // MARK: - OS info

    /// Operating system name, e.g. `iOS`.
    var osName: String { get }

    /// Operating system version, e.g. `16.1.1`.
    var osVersion: String { get }

    /// Operating system description, e.g. `iOS Version 16.1.1 (Build 20B101)`.
    var osDescription: String { get }

    /// Operating system type, e.g. `darwin`.
    var osType: String { get }
}
