//
/*
Copyright 2021 Splunk Inc.

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
import CrashReporter

var TheCrashReporter: PLCrashReporter?

func initializeCrashReporting() {
    let config = PLCrashReporterConfig(signalHandlerType: .BSD, symbolicationStrategy: PLCrashReporterSymbolicationStrategy(rawValue: 0) /* none */)
    let crashReporter_ = PLCrashReporter(configuration: config)
    if crashReporter_ == nil {
        debug_log("Cannot enable PLCrashReporter")
        return
    }
    let crashReporter = crashReporter_!
    let success = crashReporter.enable()
    debug_log("PLCrashReporter enabled: "+success.description)
    if !success {
        return
    }
    TheCrashReporter = crashReporter
    updateCrashReportSessionId()
    // Now for the pending report if there is one
    if !crashReporter.hasPendingCrashReport() {
        return
    }
    debug_log("Had a pending crash report")
    do {
        let data = crashReporter.loadPendingCrashReportData()
        try loadPendingCrashReport(data)
    } catch {
        debug_log("Error loading crash report: \(error)")
    }
    crashReporter.purgePendingCrashReport()
}

func updateCrashReportSessionId() {
    DispatchQueue.main.async {
        TheCrashReporter?.customData = getRumSessionId().data(using: .utf8)
    }
}

func loadPendingCrashReport(_ data: Data!) throws {
    debug_log("Loading crash report of size \(data?.count as Any)")
    let report = try PLCrashReport(data: data)
    let oldSessionId = String(decoding: report.customData, as: UTF8.self)
    // Turn the report into a span
    let tracer = buildTracer()
    let now = Date()
    let span = tracer.spanBuilder(spanName: "crash.report").setStartTime(time: now).setNoParent().startSpan()
    span.setAttribute(key: "component", value: "error")
    span.setAttribute(key: "crash.rumSessionId", value: oldSessionId)
    span.setAttribute(key: "error", value: true)
    span.addEvent(name: "crash.timestamp", timestamp: report.systemInfo.timestamp)
    span.setAttribute(key: "exception.type", value: report.signalInfo.name)
    span.setAttribute(key: "crash.address", value: report.signalInfo.address.description)
    for case let thread as PLCrashReportThreadInfo in report.threads where thread.crashed {
        span.setAttribute(key: "exception.stacktrace", value: crashedThreadToStack(report: report, thread: thread))
        break
    }
    if report.hasExceptionInfo {
        span.setAttribute(key: "exception.type", value: report.exceptionInfo.exceptionName)
        span.setAttribute(key: "exception.message", value: report.exceptionInfo.exceptionReason)
    }
    span.end(time: now)
}

// FIXME this is a messy copy+paste of select bits of PLCrashReportTextForamtter
func crashedThreadToStack(report: PLCrashReport, thread: PLCrashReportThreadInfo) -> String {
    let text = NSMutableString()
    text.appendFormat("Thread %ld", thread.threadNumber)
    var frameNum = 0
    while frameNum < thread.stackFrames.count {
        let str = formatStackFrame(
            // swiftlint:disable:next force_cast
            frame: thread.stackFrames[frameNum] as! PLCrashReportStackFrameInfo,
            frameNum: frameNum,
            report: report)
        text.append(str)
        text.append("\n")
        frameNum += 1
    }
    return String(text)
}

func formatStackFrame(frame: PLCrashReportStackFrameInfo, frameNum: Int, report: PLCrashReport) -> String {
    var baseAddress: UInt64 = 0
    var pcOffset: UInt64 = 0
    var imageName = "???"
    var symbolString: String?
    let imageInfo = report.image(forAddress: frame.instructionPointer)
    if imageInfo != nil {
        imageName = imageInfo!.imageName
        imageName = URL(fileURLWithPath: imageName).lastPathComponent
        baseAddress = imageInfo!.imageBaseAddress
        pcOffset = frame.instructionPointer - imageInfo!.imageBaseAddress
    }
    if frame.symbolInfo != nil {
        let symbolName = frame.symbolInfo.symbolName
        let symOffset = frame.instructionPointer - frame.symbolInfo.startAddress
        symbolString =  String(format: "%@ + %ld", symbolName!, symOffset)
    } else {
        symbolString = String(format: "0x%lx + %ld", baseAddress, pcOffset)
    }
    return String(format: "%-4ld%-35@ 0x%016lx %@", frameNum, imageName, frame.instructionPointer, symbolString!)
}
