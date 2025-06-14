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

internal import CiscoLogger
import CrashReporter
import Foundation
import OpenTelemetryApi
import SplunkCommon

public class CrashReports {

    // MARK: - Public

    /// An instance of the Agent shared state object, which is used to obtain agent's state, e.g. a session id.
    public unowned var sharedState: AgentSharedState?

    /// An array to hold images used in active crash threads
    public var allUsedImageNames: [String] = []

    let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "CrashReports")
    private var crashReporter: PLCrashReporter?

    /// Storage of periodically sampled device data
    private var deviceDataDictionary: [CrashReportKeys: String] = [:]

    /// A reference to the Module's data publishing callback.
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
        // Setup private path for crash reports to avoid conflict with other
        // instances of PLCrashReporter present in the client app
        let fileManager = FileManager.default
        let crashDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("SplunkCrashReports", isDirectory: true)
        try? fileManager.createDirectory(at: crashDirectory, withIntermediateDirectories: true)

        let signalConfig = PLCrashReporterConfig(signalHandlerType: signalHandlerType, symbolicationStrategy: [], basePath: crashDirectory.path)
        guard let crashReporterInstance = PLCrashReporter(configuration: signalConfig) else {
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
                "Could not report, crash reporter: Not Installed."
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
            let report = try PLCrashReport(data: data)

            // Process the report
            let reportPayload = formatCrashReport(report: report)

            // Send the report to the backend
            send(crashReport: reportPayload, sharedState: sharedState)
        } catch {
            logger.log(level: .error) {
                "CrashReporter failed to load/parse with error: \(error)"
            }
            return
        }

        // Purge the report.
        crashReporter?.purgePendingCrashReport()

        // And indicate that crash occured
        logger.log(level: .warn) {
            "A crash ended the previous execution of app."
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
        } catch {
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

    // Device stats handler.  This added device stats to PLCrashReporter
    // so that it will be included in a future crash report
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

    // Device data is collected every 5 seconds and sent to PLCrashReporter
    private func startPollingForDeviceStats() {
        let repeatSeconds: Double = 5
        DispatchQueue.global(qos: .background).async {
            let timer = Timer.scheduledTimer(withTimeInterval: repeatSeconds, repeats: true) { _ in
                self.updateDeviceStats()
            }
            timer.fire()
        }
    }

    // AppState handler
    private func appStateHandler(report: PLCrashReport) -> String {
        var appState = "unknown"
        if let sharedState {
            let timebasedAppState = sharedState.applicationState(for: report.systemInfo.timestamp) ?? "unknown"

            // TODO: This mapping code should be removed in favor of returning the line above once the backend is able to support it.

            appState = switch timebasedAppState {
            case "active": "foreground"
            case "inactive", "terminate": "background"
            default: timebasedAppState
            }
        }
        return appState
    }

    // Report formatting
    private func formatCrashReport(report: PLCrashReport) -> [CrashReportKeys: Any] {

        var reportDict: [CrashReportKeys: Any] = [:]

        reportDict[.component] = "crash"
        reportDict[.error] = true

        if let systemInfo = report.systemInfo {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
            reportDict[.crashTimestamp] = formatter.string(from: systemInfo.timestamp)
            reportDict[.currentTimestamp] = formatter.string(from: Date())
        }

        if let applicationInfo = report.applicationInfo {
            reportDict[.appVersion] = applicationInfo.applicationMarketingVersion
        }

        if report.hasProcessInfo {
            reportDict[.processPath] = report.processInfo.processPath
            reportDict[.isNative] = report.processInfo.native
        }

        if let signalInfo = report.signalInfo {
            reportDict[.signalName] = signalInfo.name
            reportDict[.faultAddress] = String(signalInfo.address)
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

        // Collect threads with stack frames
        let reportThreads = allThreadsFromCrashReport(report: report)
        reportDict[.threads] = threadList(threads: reportThreads)

        // Images referenced in threads
        reportDict[.images] = imageList(images: report.images)

        // App state
        reportDict[.previousAppState] = appStateHandler(report: report)

        return reportDict
    }

    private func toAttributeValue(_ value: Any) -> AttributeValue {
        switch value {
        case let string as String:
            return .string(string)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let bool as Bool:
            return .bool(bool)
        default:
            return .string(String(describing: value))
        }
    }

    private func send(crashReport: [CrashReportKeys: Any], sharedState: (any AgentSharedState)?) {
        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(
                instrumentationName: "splunk-crash-report",
                instrumentationVersion: sharedState?.agentVersion
            )

        let crashSpan = tracer.spanBuilder(spanName: "SplunkCrashReport")
            .setStartTime(time: Date())
            .startSpan()

        for (key, value) in crashReport {
            crashSpan.setAttribute(key: key.rawValue, value: toAttributeValue(value))
        }

        crashSpan.end(time: Date())
    }
}
