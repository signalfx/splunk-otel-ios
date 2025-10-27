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
import Foundation
import OpenTelemetryApi
internal import SplunkCommon

/// The class implementing CustomTracking public API in non-operational mode.
///
/// This is especially the case when the module is stopped by remote configuration,
/// but we still need to keep the API available to the user.
final class CustomTrackingNonOperational: CustomTrackingModule {


    // MARK: - Private

    private let internalLogger: DefaultLogAgent


    // MARK: - Initialization

    init() {
        internalLogger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "LogCustomTracking")
    }


    // MARK: - Logger

    func logAccess(toApi named: String) {
        internalLogger.log(level: .notice, isPrivate: true) {
            """
            Attempt to access the API of a remotely disabled CustomTracking module. \n
            API: `\(named)`
            """
        }
    }

    func trackWorkflow(_ workflowName: String) -> any OpenTelemetryApi.Span {
        logAccess(toApi: "trackWorkflow(workflowName)")
        let span = DefaultTracer.instance.spanBuilder(spanName: workflowName).startSpan()
        span.end()
        return span
    }
}
