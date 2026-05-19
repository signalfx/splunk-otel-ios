//
/*
Copyright 2026 Splunk Inc.

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

/// Non-key constants for crash report instrumentation (span names, values, and module identity).
enum CrashReportConstants {

    // MARK: - Span and module identity

    /// Default OpenTelemetry span name for crash reports.
    static let defaultSpanName = "SplunkCrashReport"

    /// OpenTelemetry tracer instrumentation scope name.
    static let instrumentationName = "splunk-crash-report"

    /// Module event name published when a crash report is sent.
    static let moduleEventName = "device.app.crash"

    /// Value for the ``CrashReportKeys/component`` span attribute on crash spans.
    static let componentValue = "crash"

    /// Fallback when app state or serialized JSON output is unavailable.
    static let unknownValue = "unknown"

    /// Fallback when a device stat cannot be determined.
    static let unknownDeviceStatValue = "Unknown"
}
