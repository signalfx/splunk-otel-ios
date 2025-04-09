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

public class CrashReportKeys {
    static let previousAppState = "ios.state"
    static let eventName = "device.app.crash"

    static let timestamp = "crash.timestamp"
    static let actualTimestamp = "crash.observedTimestamp"
    static let freeDiskSpace = "crash.freeDiskSpace"
    static let batteryLevel = "crash.batteryLevel"
    static let freeMemory = "crash.freeMemory"
    static let appVersion = "appVersion"

    static let processPath = "crash.processPath"
    static let isNative = "crash.isNative"

    static let signalName = "signalName"
    static let faultAddress = "crash.address"

    static let exceptionName = "exceptionName"
    static let exceptionReason = "exceptionReason"
    static let exceptionStackFrames = "exceptionStackFrames"

    static let threads = "exception.threads"
    static let images = "exception.images"
    static let details = "details"
    static let component = "component"
    static let errortag = "error"

    // Stack Frame
    static let instructionPointer = "instructionPointer"
    static let imageName = "imageName"
    static let symbolName = "symbolName"

    // Thread
    static let threadNumber = "threadNumber"
    static let stackFrames = "stackFrames"
    static let isCrashedThread = "crashed"

    // Binary Image
    static let codeType = "codeType"
    static let baseAddress = "baseAddress"
    static let offset = "offset"
    static let imageSize = "imageSize"
    static let imagePath = "imagePath"
    static let imageUUID = "imageUUID"

    // Primary group key
    static let crashReportMessageName = "ios.crash_report"
}
