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
    var allUsedImageNames: [String] = []

    let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "CrashReports")

    /// A reference to the Module's data publishing callback.
    var crashReportDataConsumer: ((CrashReportsMetadata, String) -> Void)?


    // MARK: - Private

    private var crashReporter: PLCrashReporter?

    /// Storage of periodically sampled device data
    private var deviceDataDictionary: [String: String] = [:]
    private var dataUpdateTimer: Timer?

    /// Serial queue for thread-safe access to deviceDataDictionary
    private let deviceDataQueue = DispatchQueue(label: "com.splunk.crashreports.devicedata", qos: .utility)


    // MARK: - Module methods

    public required init() {}

    deinit {
        dataUpdateTimer?.invalidate()
        dataUpdateTimer = nil
    }


    // MARK: - Public methods

    public func configureCrashReporter() {
#if os(tvOS)
        let signalHandlerType = PLCrashReporterSignalHandlerType.BSD
#else
        let signalHandlerType = PLCrashReporterSignalHandlerType.mach
#endif
        // Setup private path for crash reports to avoid conflict with other
        // instances of PLCrashReporter present in the client app
        let fileManager = FileManager.default
        let crashDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SplunkCrashReports", isDirectory: true)
        try? fileManager.createDirectory(at: crashDirectory, withIntermediateDirectories: true)

        let signalConfig = PLCrashReporterConfig(
            signalHandlerType: signalHandlerType,
            symbolicationStrategy: [],
            basePath: crashDirectory.path
        )

        guard let crashReporterInstance = PLCrashReporter(configuration: signalConfig) else {
            logger.log(level: .error) {
                "PLCrashReporter failed to initialize."
            }
            return
        }
        crashReporter = crashReporterInstance
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

            // Fetch the crash timestamp
            var timestamp = Date()  // Default to now, if no sytemInfo, should not ever happen
            if let systemInfo = report.systemInfo {
                timestamp = report.systemInfo.timestamp
            }
            else {
                logger.log(level: .error) {
                    "CrashReporter failed to report systemInfo timestamp"
                }
            }

            // Send the report to the backend
            send(crashReport: reportPayload, sharedState: sharedState, timestamp: report.systemInfo.timestamp)
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
    public func initializeCrashReporter() -> Bool {

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

        // async in order to load session.id
        DispatchQueue.main.async { [weak self] in
            self?.updateDeviceStats()
        }
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

    // Device stats handler.  This added device stats and Session ID to PLCrashReporter
    // so that it will be included in a future crash report
    private func updateDeviceStats() {
        deviceDataQueue.async {
            do {
                if let sessionId = self.sharedState?.sessionId {
                    self.deviceDataDictionary["sessionId"] = sessionId
                }
                self.deviceDataDictionary["battery"] = CrashReportDeviceStats.batteryLevel
                self.deviceDataDictionary["disk"] = CrashReportDeviceStats.freeDiskSpace
                self.deviceDataDictionary["memory"] = CrashReportDeviceStats.freeMemory
                let customData = try NSKeyedArchiver.archivedData(
                    withRootObject: self.deviceDataDictionary,
                    requiringSecureCoding: false
                )

                // Update crash reporter on main queue since it might touch UI-related properties
                DispatchQueue.main.async {
                    self.crashReporter?.customData = customData
                }
            } catch {
                // We have failed to archive the custom data dictionary.
                self.logger.log(level: .warn) {
                    "Failed to add the device stats to the crash reports data."
                }
            }
        }
    }

    public func crashReportUpdateScreenName(_ screenName: String) {
        deviceDataQueue.async {
            self.deviceDataDictionary["screenName"] = screenName
        }
        updateDeviceStats()
    }

    // Device data and Session ID is collected every 5 seconds and sent to PLCrashReporter
    private func startPollingForDeviceStats() {
        let repeatSeconds: Double = 5
        dataUpdateTimer = Timer.scheduledTimer(withTimeInterval: repeatSeconds, repeats: true) { _ in
            self.updateDeviceStats()
        }
    }

    // AppState handler
    private func appStateHandler(report: PLCrashReport) -> String {
        var appState = "unknown"
        if let sharedState {
            let timebasedAppState = sharedState.applicationState(for: report.systemInfo.timestamp) ?? "unknown"

            // TODO: This mapping code should be removed in favor of returning the line above
            // once the backend is able to support it.

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

        do {
            if let customData = report.customData,
               let unarchivedData = try NSKeyedUnarchiver.unarchivedDictionary(
                   ofKeyClass: NSString.self,
                   objectClass: NSString.self,
                   from: customData
               ) as? [String: String] {

                if let sessionId = unarchivedData["sessionId"] {
                    reportDict[.sessionId] = sessionId
                }

                reportDict[.batteryLevel] = unarchivedData["battery"]
                reportDict[.freeMemory] = unarchivedData["disk"]
                reportDict[.freeDiskSpace] = unarchivedData["memory"]
                reportDict[.screenName] = unarchivedData["screenName"]
            }
        } catch {
            logger.log(level: .warn) {
                "Crash reporter could not report custom data, error: \(error)"
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

    private func send(crashReport: [CrashReportKeys: Any], sharedState: (any AgentSharedState)?, timestamp: Date) {
        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(
                instrumentationName: "splunk-crash-report",
                instrumentationVersion: sharedState?.agentVersion
            )

        let crashSpan = tracer.spanBuilder(spanName: "SplunkCrashReport")
            .setStartTime(time: timestamp)
            .startSpan()

        for (key, value) in crashReport {
            crashSpan.setAttribute(key: key.rawValue, value: toAttributeValue(value))
        }

        crashSpan.end(time: timestamp)
    }
}
