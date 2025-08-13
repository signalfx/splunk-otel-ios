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

// Static strings for crash report keys

/// An enumeration of standardized keys used in crash reports.
///
/// These keys provide a consistent structure for accessing attributes within a crash report payload.
public enum CrashReportKeys: String {
    /// The state of the application just before the crash (e.g., "foreground", "background").
    case previousAppState = "ios.state"

    /// The timestamp indicating when the crash occurred.
    case crashTimestamp = "crash.timestamp"
    /// The timestamp indicating when the crash report was processed.
    case currentTimestamp = "crash.observedTimestamp"
    /// The amount of free disk space on the device at the time of the crash.
    case freeDiskSpace = "crash.freeDiskSpace"
    /// The battery level of the device at the time of the crash.
    case batteryLevel = "crash.batteryLevel"
    /// The amount of free memory on the device at the time of the crash.
    case freeMemory = "crash.freeMemory"
    case screenName = "screen.name"

    /// The file path of the crashed process.
    case processPath = "crash.processPath"
    /// A Boolean value indicating whether the crash was in native code.
    case isNative = "crash.isNative"

    /// The name of the signal that caused the crash (e.g., `SIGSEGV`).
    case signalName
    /// The memory address where the fault occurred.
    case faultAddress = "crash.address"

    /// The name of the uncaught exception that caused the crash.
    case exceptionName = "exception.type"
    /// The reason message associated with the uncaught exception.
    case exceptionReason = "exception.message"

    /// A collection of all active threads at the time of the crash.
    case threads = "exception.threads"
    /// A collection of all binary images loaded in the process at the time of the crash.
    case images = "exception.images"
    /// A key for any additional, unstructured details about the crash.
    case details
    /// The component that generated the report, typically "crash".
    case component
    /// A Boolean flag indicating that the report represents an error.
    case error

    // Stack Frame
    /// The instruction pointer address within a stack frame.
    case instructionPointer
    /// The name of the binary image associated with a stack frame.
    case imageName
    /// The demangled symbol name (e.g., function name) for a stack frame.
    case symbolName

    // Thread
    /// The unique identifier for a thread.
    case threadNumber
    /// A collection of stack frames belonging to a thread.
    case stackFrames
    /// A Boolean flag indicating if this was the thread that triggered the crash.
    case isCrashedThread = "crashed"

    // Binary Image
    /// The base memory address where the binary image was loaded.
    case baseAddress
    /// The memory offset within the binary image.
    case offset
    /// The size of the binary image in memory.
    case imageSize
    /// The file system path to the binary image.
    case imagePath
    /// The unique identifier (UUID) of the binary image.
    case imageUUID

    // Session ID
    /// The session ID active at the time of the crash.
    case sessionId = "session.id"
}
