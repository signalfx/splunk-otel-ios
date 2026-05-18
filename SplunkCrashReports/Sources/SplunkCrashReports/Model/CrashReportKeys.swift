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

/// Span attribute keys for crash report telemetry.
///
/// Keys that match OpenTelemetry semantic conventions (for example ``exceptionName`` and
/// ``exceptionReason``) use the same wire names as ``SemanticConventions/Exception``.
public enum CrashReportKeys: String {

    // MARK: - Span and module identity

    /// Default OpenTelemetry span name for crash reports.
    public static let defaultSpanName = "SplunkCrashReport"

    /// OpenTelemetry tracer instrumentation scope name.
    public static let instrumentationName = "splunk-crash-report"

    /// Module event name published when a crash report is sent.
    public static let moduleEventName = "device.app.crash"

    /// Value for ``component`` on crash spans.
    public static let componentValue = "crash"

    /// Fallback when app state or serialized JSON output is unavailable.
    public static let unknownValue = "unknown"

    /// Fallback when a device stat cannot be determined.
    public static let unknownDeviceStatValue = "Unknown"


    // MARK: - Span attribute keys
    case previousAppState = "ios.app.state"

    case crashTimestamp = "crash.timestamp"
    case currentTimestamp = "crash.observedTimestamp"
    case freeDiskSpace = "crash.freeDiskSpace"
    case batteryLevel = "crash.batteryLevel"
    case freeMemory = "crash.freeMemory"
    case screenName = "screen.name"
    case buildId = "crash.app.build_id"

    case processPath = "crash.processPath"
    case isNative = "crash.isNative"

    case signalName
    case faultAddress = "crash.address"

    case exceptionName = "exception.type"
    case exceptionReason = "exception.message"

    case threads = "exception.threads"
    case images = "exception.images"
    case details
    case component
    case error

    // Stack Frame
    case instructionPointer
    case imageName
    case symbolName

    // Thread
    case threadNumber
    case stackFrames
    case isCrashedThread = "crashed"

    // Binary Image
    case baseAddress
    case offset
    case imageSize
    case imagePath
    case imageUUID

    case sessionId = "session.id"
}


/// Keys for the dictionary archived into PLCrashReporter custom data.
///
/// These are internal storage keys and differ from span attribute keys in ``CrashReportKeys``.
enum CrashReportCustomDataKeys: String {
    case sessionId = "sessionId"
    case battery = "battery"
    case disk = "disk"
    case memory = "memory"
    case screenName = "screenName"
    case buildId = "buildId"
}
