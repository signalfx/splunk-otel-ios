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
import OpenTelemetryApi
import SplunkCommon
import SplunkSession

/// The entry point for the crash reporting module.
public class CrashReports {

    // MARK: - Public

    /// Enables the crash reporting module.
    public func enable() {
        startup()
    }

    // MARK: - Internal

    /// Logger for the module.
    let logger = DefaultLogAgent(category: "SplunkCrashReports")

    /// Shared agent state.
    let sharedState: AgentSharedState?

    /// Crash reporter.
    var crashReporter: PLCrashReporter?

    /// Designated initializer.
    init(
        configuration: SplunkRumConfiguration,
        session: SessionState,
        navigation: Navigation
    ) {
        sharedState = AgentSharedState(
            configuration: configuration,
            session: session,
            navigation: navigation
        )
    }

    /// Test initializer.
    init(
        crashReporter: PLCrashReporter,
        sharedState: AgentSharedState?
    ) {
        self.crashReporter = crashReporter
        self.sharedState = sharedState
    }

    // MARK: - Crash Reporter Lifecycle

    /// Callback for the crash reporter.
    func postCrashCallback(report: PLCrashReport) {
        // The crash report is formatted and sent in a background thread.
        // This is to avoid blocking the main thread while the app is terminating.
        let backgroundTaskID = SplunkRum.createBackgroundTask()

        let formatted = formatCrashReport(report: report)
        send(crashReport: formatted, sharedState: sharedState, timestamp: Date())

        // The background task must be ended after the crash report is sent.
        SplunkRum.endBackgroundTask(backgroundTaskID)
    }

    // MARK: - Private methods

    /// Starts up crash reporter if enable is true and no debugger attached.
    private func startup() {
        if SplunkRum.isDebuggerAttached {
            logger.log(level: .info) {
                "Crash reporting is disabled while debugging."
            }
            return
        }

        // It's not safe to use PLCrashReporter in app extensions
        if isAppExtension {
            logger.log(level: .info) {
                "Crash reporting is not supported in app extensions."
            }
            return
        }

        let config = PLCrashReporterConfig(
            signalHandlerType: .bsd,
            symbolicationStrategy: .all
        )

        // swiftlint:disable:next force_unwrapping
        let reporter = PLCrashReporter(configuration: config)!

        // swiftlint:disable:next force_try
        try! reporter.enableAndReturnError()

        // swiftlint:disable:next force_try
        let data = try! reporter.loadPendingCrashReportDataAndReturnError()

        // swiftlint:disable:next force_try
        let report = try! PLCrashReport(data: data)

        postCrashCallback(report: report)

        // swiftlint:disable:next force_try
        try! reporter.purgePendingCrashReportAndReturnError()

        crashReporter = reporter
    }

    /// AppState handler.
    func appStateHandler(report: PLCrashReport) -> String {
        var appState = "unknown"
        if let sharedState {
            let timebasedAppState = sharedState.applicationState(for: report.systemInfo.timestamp) ?? "unknown"
            appState = timebasedAppState
        }

        return appState
    }

    private func send(crashReport: [CrashReportKeys: Any], sharedState: (any AgentSharedState)?, timestamp _: Date) {
        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(
                instrumentationName: "splunk-ios-crash",
                instrumentationVersion: SplunkRumVersionString
            )

        let now = Date()
        let span = tracer.spanBuilder(spanName: "crash.report").setStartTime(time: now).startSpan()

        for (key, var value) in crashReport {
            if key == .sessionId {
                span.setAttribute(key: key.rawValue, value: value as? String ?? "")
                continue
            }

            if var dict = value as? [String: Any] {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        value = jsonString
                    }
                }
                catch {
                    logger.log(level: .warn) {
                        "Crash reporter could not serialize dictionary, error: \(error)"
                    }
                }
            }

            if var array = value as? [Any] {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: array, options: .prettyPrinted)
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        value = jsonString
                    }
                }
                catch {
                    logger.log(level: .warn) {
                        "Crash reporter could not serialize array, error: \(error)"
                    }
                }
            }

            span.setAttribute(key: key.rawValue, value: AttributeValue.string(String(describing: value)))
        }

        if let sharedState {
            sharedState.addGlobalAttributes(to: span)
        }

        span.end(time: now)
    }

    /// Check if running in an app extension
    private var isAppExtension: Bool {
        Bundle.main.bundlePath.hasSuffix(".appex")
    }
}
