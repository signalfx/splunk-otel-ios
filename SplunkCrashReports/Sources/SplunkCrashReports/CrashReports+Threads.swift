//
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

import CrashReporter
import Foundation

// Support for Threads

extension CrashReports {

    func allThreadsFromCrashReport(report: PLCrashReport) -> [[CrashReportKeys: Any]] {
        var threads: [[CrashReportKeys: Any]] = []

        for thread in report.threads {
            if let thread = thread as? PLCrashReportThreadInfo {
                let thr = oneThreadFromCrashReport(thread: thread, report: report)

                threads.append(thr)
            }
        }
        return threads
    }

    private func oneThreadFromCrashReport(
        thread: PLCrashReportThreadInfo,
        report: PLCrashReport
    ) -> [CrashReportKeys: Any] {

        var oneThread: [CrashReportKeys: Any] = [:]
        oneThread[.details] = thread
        oneThread[.stackFrames] = convertStackFrames(frames: thread.stackFrames, report: report)
        return oneThread
    }

    private func convertStackFrames(frames: [Any], report: PLCrashReport) -> [Any] {

        var stackFrames: [Any] = []
        var isFirstTime = true

        guard let frames = frames as? [PLCrashReportStackFrameInfo] else {
            logger.log(level: .error) {
                "CrashReporter received incorrect stackFrame type."
            }
            return []
        }

        for stackFrame in frames {
            var frameDict: [CrashReportKeys: Any] = [:]

            var instructionPointer = stackFrame.instructionPointer
            if !isFirstTime {
                instructionPointer -= 4
            }
            isFirstTime = false

            frameDict[.instructionPointer] = instructionPointer

            let imageInfo = report.image(forAddress: instructionPointer)
            let imageName = imageInfo?.imageName
            if imageName == nil {
                logger.log(level: .warn) {
                    "Agent could not locate image for instruction pointer."
                }
                frameDict[.imageName] = "???"
            }
            else {
                frameDict[.imageName] = imageName

                // Added to limit the number of images sent
                if let imageName {
                    allUsedImageNames.append(imageName)
                }
            }

            var baseAddress: UInt64 = 0
            var offset: UInt64 = 0
            if let imageInfo {
                baseAddress = imageInfo.imageBaseAddress
                offset = instructionPointer - baseAddress
            }
            if stackFrame.symbolInfo != nil {
                let symbolName = stackFrame.symbolInfo.symbolName
                let symOffset = instructionPointer - stackFrame.symbolInfo.startAddress
                frameDict[.symbolName] = symbolName
                frameDict[.offset] = symOffset
            }
            else {
                frameDict[.baseAddress] = baseAddress
                frameDict[.offset] = offset
            }
            stackFrames.append(frameDict)
        }
        return stackFrames
    }

    /// The thread list returned as a JSON encoded string.
    func threadList(threads: [[CrashReportKeys: Any]]) -> String {
        var outputThreads: [Any] = []

        for thread in threads {

            var threadDictionary: [CrashReportKeys: Any] = [:]
            threadDictionary[.stackFrames] = thread[CrashReportKeys.stackFrames]

            if let info = thread[CrashReportKeys.details] as? PLCrashReportThreadInfo {
                threadDictionary[.threadNumber] = info.threadNumber
                threadDictionary[.isCrashedThread] = info.crashed
            }
            outputThreads.append(threadDictionary)
        }
        return convertToJSONString(outputThreads) ?? "unknown"
    }
}
