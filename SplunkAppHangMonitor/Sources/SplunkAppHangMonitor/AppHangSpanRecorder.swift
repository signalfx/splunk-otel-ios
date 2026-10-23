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
import OpenTelemetryApi
@_spi(SplunkInternal) import SplunkCommon

/// Creates and closes app-hang spans for the detector's serial worker queue.
final class AppHangSpanRecorder {

    // MARK: - Internal State

    private var activeSpan: (span: any Span, start: TimeInterval)?
    private var lastInteractionTime: TimeInterval?
    private var lastInteractionType: String?
    private var wallClockOffset: TimeInterval = 0

    private var interactionAssociationEnabled = true
    private var interactionAssociationWindow: TimeInterval = 5

    var threshold: TimeInterval = 0.25
    var hasActiveSpan: Bool {
        activeSpan != nil
    }


    // MARK: - Configuration

    func configure(
        thresholdMilliseconds: Int,
        interactionAssociationEnabled: Bool,
        interactionAssociationWindowMilliseconds: Int
    ) {
        threshold = TimeInterval(thresholdMilliseconds) / 1_000
        self.interactionAssociationEnabled = interactionAssociationEnabled
        interactionAssociationWindow = TimeInterval(interactionAssociationWindowMilliseconds) / 1_000
    }

    func updateClockOffset(at monotonicTime: TimeInterval) {
        wallClockOffset = Date().timeIntervalSince1970 - monotonicTime
    }

    func recordInteraction(at timestamp: TimeInterval, type: String) {
        guard interactionAssociationEnabled else {
            return
        }

        if let lastInteractionTime, timestamp < lastInteractionTime {
            return
        }

        lastInteractionTime = timestamp
        lastInteractionType = type
    }


    // MARK: - Span Lifecycle

    func openSpan(startingAt startTime: TimeInterval) {
        guard activeSpan == nil else {
            return
        }

        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(instrumentationName: AppHangMonitorConstants.instrumentationName)

        let span = tracer.spanBuilder(spanName: AppHangMonitorConstants.spanName)
            .setStartTime(time: date(for: startTime))
            .startSpan()

        span.clearAndSetAttribute(key: "component", value: AppHangMonitorConstants.component)
        span.clearAndSetAttribute(key: AppHangMonitorConstants.thresholdMilliseconds, value: threshold * 1_000)

        if interactionAssociationEnabled,
            let lastInteractionTime,
            startTime - lastInteractionTime <= interactionAssociationWindow,
            startTime >= lastInteractionTime
        {
            span.clearAndSetAttribute(key: AppHangMonitorConstants.interactionEvidence, value: "recent_observed")
            if let lastInteractionType {
                span.clearAndSetAttribute(key: AppHangMonitorConstants.interactionType, value: lastInteractionType)
            }
            span.clearAndSetAttribute(
                key: AppHangMonitorConstants.interactionAgeMilliseconds,
                value: (startTime - lastInteractionTime) * 1_000
            )
        }

        activeSpan = (span, startTime)
    }

    func finish(at endTime: TimeInterval, complete: Bool) {
        guard let activeSpan else {
            return
        }

        activeSpan.span.clearAndSetAttribute(
            key: AppHangMonitorConstants.durationMilliseconds,
            value: max(0, endTime - activeSpan.start) * 1_000
        )
        activeSpan.span.clearAndSetAttribute(
            key: AppHangMonitorConstants.durationIsComplete,
            value: complete
        )
        activeSpan.span.clearAndSetAttribute(
            key: AppHangMonitorConstants.outcome,
            value: complete ? "recovered" : "interrupted"
        )
        activeSpan.span.end(time: date(for: endTime))
        self.activeSpan = nil
    }


    // MARK: - Date Conversion

    private func date(for monotonicTime: TimeInterval) -> Date {
        Date(timeIntervalSince1970: monotonicTime + wallClockOffset)
    }
}
