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

import OpenTelemetryApi

/// A saved copy of the global OpenTelemetry tracer and logger providers.
///
/// Each trace processor and each log event processor registers its provider as the global one, and
/// OpenTelemetry has no way to unregister a provider. Save the globals before a test builds a pipeline,
/// and restore them when the test ends, so that later tests do not send spans into this test's pipeline.
struct OpenTelemetryGlobals {

    // MARK: - Saved providers

    /// The global tracer provider at the time of the save.
    let tracerProvider: any TracerProvider

    /// The global logger provider at the time of the save.
    let loggerProvider: any LoggerProvider


    // MARK: - Initialization

    /// Saves the current global tracer and logger providers.
    init() {
        tracerProvider = OpenTelemetry.instance.tracerProvider
        loggerProvider = OpenTelemetry.instance.loggerProvider
    }


    // MARK: - Restore

    /// Registers the saved providers as the global ones again.
    func restore() {
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
        OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
    }
}
