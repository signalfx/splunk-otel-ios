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

/// A status of agent instance.
///
/// Describes the possible states for agent in which can be during its lifecycle.
@objc(SPLKStatus)
public final class StatusObjC: NSObject {

    // MARK: - Agent status

    /// Recording is in progress.
    @objc
    public static let running = NSNumber(value: 1)

    /// Recording is not currently in progress because the agent has not been installed.
    @objc
    public static let notRunningNotInstalled = NSNumber(value: -100)

    /// Recording is not currently in progress because
    /// the agent is not supported on the current platform.
    @objc
    public static let notRunningUnsupportedPlatform = NSNumber(value: -101)

    /// Recording is not currently in progress because the agent is being sampled locally.
    @objc
    public static let notRunningSampledOut = NSNumber(value: -102)


    // MARK: - Initialization

    // Initialization is hidden from the public API
    // as we only need to work with the class type.
    override init() {}


    // MARK: - Conversion utils

    static func status(for value: NSNumber) -> Status? {
        switch value {
        case StatusObjC.running:
            return .running

        case StatusObjC.notRunningNotInstalled:
            return .notRunning(.notInstalled)

        case StatusObjC.notRunningUnsupportedPlatform:
            return .notRunning(.unsupportedPlatform)

        case StatusObjC.notRunningSampledOut:
            return .notRunning(.sampledOut)

        default:
            return nil
        }
    }

    static func value(for status: Status) -> NSNumber {
        switch status {
        case .running:
            return StatusObjC.running

        case .notRunning(.notInstalled):
            return StatusObjC.notRunningNotInstalled

        case .notRunning(.unsupportedPlatform):
            return StatusObjC.notRunningUnsupportedPlatform

        case .notRunning(.sampledOut):
            return StatusObjC.notRunningSampledOut
        }
    }
}
