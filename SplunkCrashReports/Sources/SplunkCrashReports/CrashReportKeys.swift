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

// Static strings for crash report keys

public enum CrashReportKeys: String {
    case previousAppState = "ios.state"

    case crashTimestamp = "crash.timestamp"
    case currentTimestamp = "crash.observedTimestamp"
    case freeDiskSpace = "crash.freeDiskSpace"
    case batteryLevel = "crash.batteryLevel"
    case freeMemory = "crash.freeMemory"
    case appVersion = "appVersion"

    case processPath = "crash.processPath"
    case isNative = "crash.isNative"

    case signalName = "signalName"
    case faultAddress = "crash.address"

    case exceptionName = "exception.type"
    case exceptionReason = "exception.message"

    case threads = "exception.threads"
    case images = "exception.images"
    case details = "details"
    case component = "component"
    case error = "error"

    // Stack Frame
    case instructionPointer = "instructionPointer"
    case imageName = "imageName"
    case symbolName = "symbolName"

    // Thread
    case threadNumber = "threadNumber"
    case stackFrames = "stackFrames"
    case isCrashedThread = "crashed"

    // Binary Image
    case baseAddress = "baseAddress"
    case offset = "offset"
    case imageSize = "imageSize"
    case imagePath = "imagePath"
    case imageUUID = "imageUUID"

    // Primary group key
    case crashReportMessageName = "ios.crash_report"
}
