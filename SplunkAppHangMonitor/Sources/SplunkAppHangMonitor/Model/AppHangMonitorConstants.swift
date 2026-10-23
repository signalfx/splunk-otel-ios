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

enum AppHangMonitorConstants {

    // MARK: - Spans

    static let spanName = "app.hang"
    static let instrumentationName = "splunk-app-hang-monitor"
    static let component = "ui"


    // MARK: - Attributes

    static let durationMilliseconds = "app.hang.duration_ms"
    static let thresholdMilliseconds = "app.hang.threshold_ms"
    static let durationIsComplete = "app.hang.duration.is_complete"
    static let outcome = "app.hang.outcome"
    static let interactionEvidence = "app.hang.interaction.evidence"
    static let interactionType = "app.hang.interaction.type"
    static let interactionAgeMilliseconds = "app.hang.interaction.time_since_ms"


    // MARK: - Monitoring

    static let watchdogInterval = DispatchTimeInterval.milliseconds(25)
}
