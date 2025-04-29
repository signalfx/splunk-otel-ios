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

internal import CiscoLogger
import Foundation
import SplunkCommon
internal import SplunkCrashReporter

public class CrashReports {

    // MARK: - Public

    /// An instance of the Agent shared state object, which is used to obtain agent's state, e.g. a session id.
    public unowned var sharedState: AgentSharedState?

    private var crashReporter: SPLKPLCrashReporter?
    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "CrashReports")
    private var allUsedImageNames: [String] = []
    private var deviceDataDictionary: [CrashReportKeys: String] = [:]

    // A reference to the Module's data publishing callback.
    var crashReportDataConsumer: ((CrashReportsMetadata, String) -> Void)?


    // MARK: - Module methods

    public required init() {}


    // MARK: - Public methods

    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any RemoteModuleConfiguration)?) {
#if os(tvOS)
        let signalHandlerType = PLCrashReporterSignalHandlerType.BSD
#else
        let signalHandlerType = PLCrashReporterSignalHandlerType.mach
#endif

        let signalConfig = SPLKPLCrashReporterConfig(signalHandlerType: signalHandlerType, symbolicationStrategy: [])
        guard let crashReporterInstance = SPLKPLCrashReporter(configuration: signalConfig) else {
            logger.log(level: .error) {
                "PLCrashReporter failed to initialize."
            }
            return
        }
        crashReporter = crashReporterInstance

        // Initialize CrashReports module
        _ = initializeCrashReporter()
    }

    /// Check whether a crash ended the previous run of the app
    public func reportCrashIfPresent() {

        guard crashReporter != nil else {
            logger.log(level: .warn) {
                "Could not report crash reporter: Not Installed."
            }
            return
        }

        let didCrash = crashReporter?.hasPendingCrashReport()

        guard didCrash ?? false else {
            logger.log(level: .info) {
                "No Crash Report found."
            }
            return
        }

        do {
            allUsedImageNames.removeAll()
            let data = try crashReporter?.loadPendingCrashReportDataAndReturnError()

            // Retrieving crash reporter data.
            let report = try SPLKPLCrashReport(data: data)

            // And collect stack frames
            let stackFrames = stackFramesFromCrashReport(report: report)

            // At this point we should send the report to the collector
            let reportPayload = formatCrashReport(report: report, stackFrames: stackFrames)
            let jsonPayload = CrashReportJSON.convertDictionaryToJSONString(reportPayload)

            guard let jsonPayload else {
                logger.log(level: .error) {
                    "CrashReporter failed to parse the Crash Report JSON payload."
                }
                return
            }

            guard
                let systemInfo = report.systemInfo,
                let timestamp = systemInfo.timestamp
            else {
                logger.log(level: .error) {
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
            logger.log(level: .error) {
                "CrashReporter failed to load/parse with error: \(error)"
            }
            return
        }

        // Purge the report.
        crashReporter?.purgePendingCrashReport()

        // And indicate that crash occured
        logger.log(level: .warn) {
            "Crash ended previous execution of app."
        }
    }

    // MARK: - Private methods

    // Starts up crash reporter if enable is true and no debugger attached
    private func initializeCrashReporter() -> Bool {

        guard crashReporter != nil else {
            logger.log(level: .warn) {
                "Could not enable crash reporter: Not Installed"
            }
            return false
        }

        guard !isDebuggerAttached() else {
            logger.log(level: .warn) {
                "Could not enable crash reporter: Debugger Attached."
            }
            return false
        }

        do {
            try crashReporter?.enableAndReturnError()
        } catch let error {
            logger.log(level: .error) {
                "Could not enable crash reporter: \(error)"
            }
            return false
        }

        // Init device stats collection
        updateDeviceStats()
        startPollingForDeviceStats()

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

    // Device stats handler

    private func updateDeviceStats() {
        do {
            deviceDataDictionary[.batteryLevel] = CrashReportDeviceStats.batteryLevel
            deviceDataDictionary[.freeDiskSpace] = CrashReportDeviceStats.freeDiskSpace
            deviceDataDictionary[.freeMemory] = CrashReportDeviceStats.freeMemory
            let customData = try NSKeyedArchiver.archivedData(withRootObject: deviceDataDictionary, requiringSecureCoding: false)
            crashReporter?.customData = customData
        } catch {
            // We have failed to archive the custom data dictionary.
            logger.log(level: .warn) {
                "Failed to add the device stats to the crash reports data."
            }
        }
    }

    /*
     Will poll every 5 seconds to update the device stats.
     */
    private func startPollingForDeviceStats() {
        let repeatSeconds: Double = 5
        DispatchQueue.global(qos: .background).async {
            let timer = Timer.scheduledTimer(withTimeInterval: repeatSeconds, repeats: true) { _ in
                self.updateDeviceStats()
            }
            timer.fire()
        }
    }

    // Report formatting

    private func stackFramesFromCrashReport(report: SPLKPLCrashReport) -> [CrashReportKeys: Any] {
        var stackFrames: [CrashReportKeys: Any] = [:]
        var threads: [Any] = []

        for thread in report.threads {
            if let thread = thread as? SPLKPLCrashReportThreadInfo {
                let thr = threadFromReport(thread: thread, report: report)

                threads.append(thr)
            }
        }
        stackFrames[CrashReportKeys.threads] = threads

        return stackFrames
    }

    private func formatCrashReport(report: SPLKPLCrashReport, stackFrames: [CrashReportKeys: Any]) -> [CrashReportKeys: Any] {

        var reportDict: [CrashReportKeys: Any] = [:]

        reportDict[.component] = "crash"
        reportDict[.error] = true

        if report.systemInfo != nil {
            reportDict[.crashTimestamp] = report.systemInfo.timestamp!
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
            reportDict[.currentTimestamp] = formatter.string(from: Date())
        }
        if report.applicationInfo != nil {
            reportDict[.appVersion] = report.applicationInfo.applicationMarketingVersion
        }
        if report.hasProcessInfo {
            reportDict[.processPath] = report.processInfo.processPath
            reportDict[.isNative] = report.processInfo.native ? "1" : "0"
        }
        if report.signalInfo != nil {
            reportDict[.signalName] = report.signalInfo.name
            reportDict[.faultAddress] = String(report.signalInfo.address)
        }
        if report.hasExceptionInfo {
            reportDict[.exceptionName] = report.exceptionInfo.exceptionName ?? ""
            reportDict[.exceptionReason] = report.exceptionInfo.exceptionReason ?? ""
        }
        if report.customData != nil {
            let customData = NSKeyedUnarchiver.unarchiveObject(with: report.customData) as? [CrashReportKeys: String]
            if customData != nil {
                reportDict[.batteryLevel] = customData![.batteryLevel]
                reportDict[.freeMemory] = customData![.freeMemory]
                reportDict[.freeDiskSpace] = customData![.freeDiskSpace]
            }
        }

        let stackFramesSlice = stackFrames[CrashReportKeys.threads]
        if let stackFramesSlice = stackFramesSlice as? [[CrashReportKeys: Any]] {
            reportDict[.threads] = threadList(frames: stackFramesSlice)
        }

        reportDict[.images] = imageList(images: report.images)

        var crashPayload: [CrashReportKeys: Any] = [:]
        crashPayload[.crashReportMessageName] = reportDict

        // Place app state as a sibling to the crash report
        crashPayload[.previousAppState] = "unknown"
        if let sharedState {

            // TODO: In a post GA release, once the backend is able to support we should enable this line of code and remove the 'mapping' code below
            // crashPayload[.previousAppState] = sharedState.applicationState(for: report.systemInfo.timestamp) ?? "unknown"

            // TODO: As related to above, this mapping code should be removed in favor of the line above once the backend is able to support it.
            let appState = sharedState.applicationState(for: report.systemInfo.timestamp) ?? "unknown"

            switch appState {
            case "active":
                crashPayload[.previousAppState] = "foreground"
            case "inactive":
                crashPayload[.previousAppState] = "background"
            case "terminate":
                crashPayload[.previousAppState] = "background"
            default:
                crashPayload[.previousAppState] = appState
            }
            // End of mapping code
        }
        return crashPayload
    }

    private func convertStackFrames(frames: [Any], report: SPLKPLCrashReport) -> [Any] {

        var stackFrames: [Any] = []
        var isFirstTime = true

        guard let frames = frames as? [SPLKPLCrashReportStackFrameInfo] else {
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
            } else {
                frameDict[.imageName] = imageName
                allUsedImageNames.append(imageName!)
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
            } else {
                frameDict[.baseAddress] = baseAddress
                frameDict[.offset] = offset
            }
            stackFrames.append(frameDict)
        }
        return stackFrames
    }

    private func threadFromReport(thread: SPLKPLCrashReportThreadInfo, report: SPLKPLCrashReport) -> [CrashReportKeys: Any] {

        var oneThread: [CrashReportKeys: Any] = [:]
        oneThread[.details] = thread
        oneThread[.stackFrames] = convertStackFrames(frames: thread.stackFrames, report: report)
        return oneThread
    }

    private func threadList(threads: [[CrashReportKeys: Any]], threadKey: CrashReportKeys) -> [Any] {
        var outputThreads: [Any] = []

        for thread in threads {

            var threadDictionary: [CrashReportKeys: Any] = [:]
            threadDictionary[.stackFrames] = thread[CrashReportKeys.stackFrames]

            if let info = thread[CrashReportKeys.details] as? SPLKPLCrashReportThreadInfo {
                threadDictionary[.threadNumber] = info.threadNumber
                threadDictionary[threadKey] = info.crashed
            }
            outputThreads.append(threadDictionary)
        }
        return outputThreads
    }

    private func threadList(frames: [[CrashReportKeys: Any]]) -> [Any] {
        return threadList(threads: frames, threadKey: .isCrashedThread)
    }

    private func imageList(images: [Any]) -> [Any] {
        var outputImages: [Any] = []
        for image in images {
            var imageDictionary: [CrashReportKeys: Any] = [:]
            guard let image = image as? SPLKPLCrashReportBinaryImageInfo else {
                continue
            }
            // Only add the image to the list if it was noted in the stack traces
            if allUsedImageNames.contains(image.imageName) {
                imageDictionary[.baseAddress] = image.imageBaseAddress
                imageDictionary[.imageSize] = image.imageSize
                imageDictionary[.imagePath] = image.imageName
                imageDictionary[.imageUUID] = image.imageUUID

                outputImages.append(imageDictionary)
            }
        }
        return outputImages
    }
}
