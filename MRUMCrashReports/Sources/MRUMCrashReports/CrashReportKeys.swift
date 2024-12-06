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

    static let operatingSystem = "operatingSystem"
    static let architecture = "architecture"
    static let osVersion = "osVersion"
    static let osBuild = "osBuild"
    static let timestamp = "timestamp"
    static let actualTimestamp = "actualTimestamp"
    
    static let hardwareModel = "hardwareModel"
    static let cpuType = "cpuType"
    static let cpuCount = "cpuCount"
    static let cpuLogicalCount = "cpuLogicalCount"
    
    static let appBundleId = "appBundleId"
    static let appVersion = "appVersion"
    
    static let processName = "processName"
    static let processId = "processId"
    static let processPath = "processPath"
    static let parentProcessName = "parentProcessName"
    static let parentProcessId = "parentProcessId"
    static let isNative = "isNative"
    
    static let signalName = "signalName"
    static let signalCode = "signalCode"
    static let faultAddress = "faultAddress"
    
    static let exceptionName = "exceptionName"
    static let exceptionReason = "exceptionReason"
    static let exceptionStackFrames = "exceptionStackFrames"
    
    static let threads = "threads"
    static let images = "images"
    static let details = "details"
    
    // Register
    static let registerName = "registerName"
    static let registerValue = "registerValue"
    
    // Stack Frame
    static let instructionPointer = "instructionPointer"
    static let imageName = "imageName"
    static let symbolName = "symbolName"
    static let symbolOffset = "symbolOffset"
    static let nearestSymbolOffset = "nearestSymbolOffset"

    // Thread
    static let threadNumber = "threadNumber"
    static let stackFrames = "stackFrames"
    static let isCrashedThread = "isIssueThread"
    static let isErrorThread = "isIssueThread"
    static let isANRThread = "isIssueThread"
    static let registers = "registers"
    
    // CPU Type
    static let cType = "cpuType"
    static let cSubType = "subType"
    
    // Binary Image
    static let codeType = "codeType"
    static let baseAddress = "baseAddress"
    static let imageSize = "imageSize"
    static let imagePath = "imagePath"
    static let imageUUID = "imageUUID"

    // Prior run holdover keys
    static let majorVersionAtCrash = "appMajorVersionAtCrash"
    static let minorVersionAtCrash = "appMinorVersionAtCrash"
    static let systemVersionAtCrash = "osVersionAtCrash"

    // Primary group key
    static let crashReportMessageName = "ios.crash_report"
    
    // Logging keys
    static let scopeName = "ios-mrum"
    static let versionKey = "appdynamics.agent.version"
    static let eventDomainKey = "event.domain"
    static let eventNameKey = "event.name"
    static let eventDomain = "mrum"
    // TODO: MRUM_AC-985 - Change event.name value to device.app.crash
    static let eventName = "device.app.crash"
}
