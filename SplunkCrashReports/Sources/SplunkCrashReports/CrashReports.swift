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
internal import SplunkCrashReporter
import SplunkLogger
import SplunkSharedProtocols

public class CrashReports {

    // MARK: - Public

    /// An instance of the Agent shared state object, which is used to obtain agent's state, e.g. a session id.
    public unowned var sharedState: AgentSharedState?

    private var crashReporter: SPLKPLCrashReporter?
    private let internalLogger = InternalLogger(configuration: .crashReporter(category: "CrashReporter"))
    private var allUsedImageNames: Array <String> = []

    // A reference to the Module's data publishing callback.
    var crashReportDataConsumer: ((CrashReportsMetadata, String) -> Void)?

    // MARK: - Module methods

    public required init() {
    }

    // MARK: - Public methods

    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any RemoteModuleConfiguration)?) {
#if os(tvOS)
        let signalHandlerType = PLCrashReporterSignalHandlerType.BSD
#else
        let signalHandlerType = PLCrashReporterSignalHandlerType.mach
#endif

        let signalConfig = SPLKPLCrashReporterConfig(signalHandlerType: signalHandlerType, symbolicationStrategy: [])
        guard let crashReporterInstance = SPLKPLCrashReporter(configuration: signalConfig) else {
            self.internalLogger.log(level: .error) {
                "PLCrashReporter failed to initialize."
            }
            return
        }
        crashReporter = crashReporterInstance

        // Initialize CrashReports module
        _ = initializeCrashReporter()
    }

    /// Check whether a crash ended the previous run of the app
    public func reportCrashIfPresent() -> Void {

        guard crashReporter != nil else {
            self.internalLogger.log(level: .warn) {
                "Could not report crash reporter: Not Installed."
            }
            return
        }

        let didCrash = crashReporter?.hasPendingCrashReport()

        guard didCrash ?? false else {
            self.internalLogger.log(level: .info) {
                "No Crash Report found."
            }
            return
        }

        do {
            let data = try crashReporter?.loadPendingCrashReportDataAndReturnError()

            // Retrieving crash reporter data.
            let report = try SPLKPLCrashReport(data: data)

            // And collect stack frames
            let stackFrames = stackFramesFromCrashReport(report: report)

            // At this point we should send the report to the collector
            let reportPayload =  formatCrashReport(report: report, stackFrames: stackFrames)
            let jsonPayload = CrashReportJSON.convertDictionaryToJSONString(reportPayload)

            guard let jsonPayload else {
                self.internalLogger.log(level: .error) {
                    "CrashReporter failed to parse the Crash Report JSON payload."
                }
                return
            }

            guard
                let systemInfo = report.systemInfo,
                let timestamp = systemInfo.timestamp
            else {
                self.internalLogger.log(level: .error) {
                    "CrashReporter did not receive a valid system info block."
                }
                return
            }

            // Send the serialized Crash Report to the Module data consumer for processing.
            self.crashReportDataConsumer?(
                CrashReportsMetadata(timestamp: timestamp),
                jsonPayload
            )
        } catch let error {
            self.internalLogger.log(level: .error) {
                "CrashReporter failed to load/parse with error: \(error)"
            }
            return
        }

        // Purge the report.
        crashReporter?.purgePendingCrashReport()

        // And indicate that crash occured
        self.internalLogger.log(level: .warn) {
            "Crash ended previous execution of app."
        }
    }

    // MARK: - Private methods

    // Starts up crash reporter if enable is true and no debugger attached
    private func initializeCrashReporter() -> Bool {
        
        guard crashReporter != nil else {
            self.internalLogger.log(level: .warn) {
                "Could not enable crash reporter: Not Installed"
            }
            return false
        }

        guard !isDebuggerAttached() else {
            self.internalLogger.log(level: .warn) {
                "Could not enable crash reporter: Debugger Attached."
            }
            return false
        }

        do {
            try crashReporter?.enableAndReturnError()
        } catch let error {
            self.internalLogger.log(level: .error) {
                "Could not enable crash reporter: \(error)"
            }
            return false
        }
        return true
    }
    
    // Returns true if debugger is attached
    private func isDebuggerAttached() -> Bool {
        var debuggerIsAttached = false

        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var info = kinfo_proc()
        var infoSize = MemoryLayout<kinfo_proc>.size

        _ = name.withUnsafeMutableBytes { (nameBytePtr: UnsafeMutableRawBufferPointer) -> Bool in
            guard let nameBytesBlindMemory = nameBytePtr.bindMemory(to: Int32.self).baseAddress else {
                return false
            }

            return sysctl(nameBytesBlindMemory, 4, &info, &infoSize, nil, 0) != -1
        }

        if !debuggerIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0 {
            debuggerIsAttached = true
        }

        return debuggerIsAttached
    }


    // Report formatting
    
    private func stackFramesFromCrashReport(report: SPLKPLCrashReport) -> Dictionary<String, Any> {
        var stackFrames: [String:Any] = [:]
        var threads: Array<Any> = []

        for thread in report.threads {
            if let thread = thread as? SPLKPLCrashReportThreadInfo {
                let thr = threadFromReport(thread: thread, report: report)

                threads.append(thr)
            }
        }
        stackFrames[CrashReportKeys.threads] = threads

        stackFrames[CrashReportKeys.exceptionStackFrames] = nil
        if report.hasExceptionInfo {
            stackFrames[CrashReportKeys.exceptionStackFrames] = convertStackFrames(frames: report.exceptionInfo.stackFrames, report: report)
        }
        return stackFrames
    }
    
    private func formatCrashReport(report: SPLKPLCrashReport, stackFrames: Dictionary<String, Any>) -> Dictionary<String, Any> {
        
        var reportDict: [String:Any] = [:]
        
        if ((report.systemInfo) != nil) {
            reportDict[CrashReportKeys.timestamp] = "\(report.systemInfo.timestamp!)"
            reportDict[CrashReportKeys.actualTimestamp] = "\(report.systemInfo.timestamp!)"
        }
        
        if (report.applicationInfo != nil) {
            reportDict[CrashReportKeys.appVersion] = report.applicationInfo.applicationMarketingVersion
        }
        
        if report.hasProcessInfo {
            reportDict[CrashReportKeys.processPath] = report.processInfo.processPath
            reportDict[CrashReportKeys.isNative] = report.processInfo.native ? "1" : "0"
        }
        
        if (report.signalInfo != nil) {
            reportDict[CrashReportKeys.signalName] = report.signalInfo.name
            reportDict[CrashReportKeys.faultAddress] = String(report.signalInfo.address)
        }
        
        if (report.hasExceptionInfo) {
            if(report.exceptionInfo.exceptionName != nil) {
                reportDict[CrashReportKeys.exceptionName] = report.exceptionInfo.exceptionName
            }
            else {
                reportDict[CrashReportKeys.exceptionName] = ""
            }
            if(report.exceptionInfo.exceptionReason != nil) {
                reportDict[CrashReportKeys.exceptionReason] = report.exceptionInfo.exceptionReason
            }
            else {
                reportDict[CrashReportKeys.exceptionReason] = ""
            }
            if(stackFrames[CrashReportKeys.exceptionStackFrames] != nil)  {
                reportDict[CrashReportKeys.exceptionStackFrames] = stackFrames[CrashReportKeys.exceptionStackFrames]
            }
        }
        
        let stackFramesSlice = stackFrames[CrashReportKeys.threads]
        if let stackFramesSlice = stackFramesSlice as? Array<Dictionary<String, Any>> {
            reportDict[CrashReportKeys.threads] = threadList(frames: stackFramesSlice)
        }

        reportDict[CrashReportKeys.images] = imageList(images: report.images)
        
        var crashPayload: [String:Any] = [:]
        crashPayload[CrashReportKeys.crashReportMessageName] = reportDict
        
        // Place app state as a sibling to the crash report
        crashPayload[CrashReportKeys.previousAppState] = "unknown"
        if let sharedState {
            
            // TODO: In a post GA release, once the backend is able to support we should enable this line of code and remove the 'mapping' code below
            // crashPayload[CrashReportKeys.previousAppState] = sharedState.applicationState(for: report.systemInfo.timestamp) ?? "unknown"

            // TODO: As related to above, this mapping code should be removed in favor of the line above once the backend is able to support it.
            let appState = sharedState.applicationState(for: report.systemInfo.timestamp) ?? "unknown"

            switch appState {
            case "active":
                crashPayload[CrashReportKeys.previousAppState] = "foreground"

            case "inactive":
                crashPayload[CrashReportKeys.previousAppState] = "background"

            case "terminate":
                crashPayload[CrashReportKeys.previousAppState] = "background"

            default:
                crashPayload[CrashReportKeys.previousAppState] = appState
            }
            // End of mapping code
        }
        return crashPayload
    }

    private func convertStackFrames(frames: Array<Any>, report: SPLKPLCrashReport) -> Array<Any> {
        
        var stackFrames: Array<Any> = []
        var isFirstTime: Bool = true
        
        guard let frames = frames as? [SPLKPLCrashReportStackFrameInfo] else {
            // TODO: - Check the correctness of the return value.
            self.internalLogger.log(level: .error) {
                "CrashReporter received incorrect stackFrame type."
            }
            return []
        }
        
        for stackFrame in frames {
            var frameDict: [String:Any] = [:]

            var instructionPointer = stackFrame.instructionPointer
            if (!isFirstTime) {
                instructionPointer -= 4
            }
            isFirstTime = false
            
            frameDict[CrashReportKeys.instructionPointer] = instructionPointer

            let imageInfo = report.image(forAddress: instructionPointer)
            let imageName = imageInfo?.imageName
            if(imageName == nil) {
                self.internalLogger.log(level: .warn) {
                    "Agent could not locate image for instruction pointer."
                }
            }
            else {
                frameDict[CrashReportKeys.imageName] = imageName
                allUsedImageNames.append(imageName!)
            }
            
            var baseAddress: UInt64 = 0
            var offset: UInt64 = 0
            if imageInfo != nil {
                baseAddress = imageInfo!.imageBaseAddress
                offset = instructionPointer - baseAddress
            }
            if stackFrame.symbolInfo != nil {
                let symbolName = stackFrame.symbolInfo.symbolName
                let symOffset = instructionPointer - stackFrame.symbolInfo.startAddress
                frameDict[CrashReportKeys.symbolName] = symbolName
                frameDict[CrashReportKeys.offset] = symOffset
            } else {
                frameDict[CrashReportKeys.baseAddress] = baseAddress
                frameDict[CrashReportKeys.offset] = offset
            }
            stackFrames.append(frameDict)
        }
        return stackFrames
    }
    
    private func threadFromReport(thread: SPLKPLCrashReportThreadInfo, report: SPLKPLCrashReport) -> Dictionary<String, Any> {
        
        var oneThread: [String:Any] = [:]
        oneThread[CrashReportKeys.details] = thread
        oneThread[CrashReportKeys.stackFrames] = convertStackFrames(frames: thread.stackFrames, report: report)
        return oneThread
    }
    
    private func threadList(threads: Array<Dictionary<String, Any>>, threadKey: String) -> Array<Any> {
        var outputThreads: Array<Any> = []
        
        for thread in threads {
            
            var threadDictionary: [String:Any] = [:]
            threadDictionary[CrashReportKeys.stackFrames] = thread[CrashReportKeys.stackFrames]

            if let info = thread[CrashReportKeys.details] as? SPLKPLCrashReportThreadInfo {
                threadDictionary[CrashReportKeys.threadNumber] = info.threadNumber
                threadDictionary[threadKey] = info.crashed
            }
            outputThreads.append(threadDictionary)
        }
        return outputThreads

    }
    
    private func threadList(frames: Array<Dictionary<String, Any>>) -> Array<Any> {
        return threadList(threads: frames, threadKey: CrashReportKeys.isCrashedThread)
    }
        
    private func imageList(images: Array<Any>) -> Array<Any> {
        var outputImages: Array<Any> = []
        for image in images {
            var imageDictionary: [String:Any] = [:]
            guard let image = image as? SPLKPLCrashReportBinaryImageInfo else {
                continue
            }
            // Only add the image to the list if it was noted in the stack traces
            if(allUsedImageNames.contains(image.imageName)) {
                imageDictionary[CrashReportKeys.baseAddress] = image.imageBaseAddress
                imageDictionary[CrashReportKeys.imageSize] = image.imageSize
                imageDictionary[CrashReportKeys.imagePath] = image.imageName
                imageDictionary[CrashReportKeys.imageUUID] = image.imageUUID
                
                outputImages.append(imageDictionary)
            }
        }
        return outputImages
    }    
}
