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
import OpenTelemetryApi
import OpenTelemetrySdk
import Testing

@testable import SplunkAgent
@testable import SplunkOpenTelemetry

/// A span that the customer span interceptor changed releases no held `session.start`.
///
/// Each test builds its own session and storage, so suites that run in parallel share no state.
@Suite
struct SessionIdInterceptorHeldStartTests {

    // MARK: - Tests

    /// A span whose `session.id` the interceptor changes releases no held `session.start`, of either session.
    @Test
    func changedIdSpanReleasesNoHeldStart() {
        let (session, replacedSessionId) = makeSessionHoldingTwoStarts()
        let sessionId = session.currentSessionId
        let releaseHeldStarts: ([SpanData]) -> Void = { spans in
            for span in spans {
                if case let .string(sessionId) = span.attributes["session.id"] {
                    session.trackAcceptedTelemetry(forSessionId: sessionId)
                }
            }
        }
        let pipeline = SessionPolicySpanExporter(
            proxy: SpanInterceptorExporter(
                with: { span in Self.moveSpanNamedChanged(span, to: replacedSessionId) },
                proxy: MockSpanExporter(),
                requiresUnchangedSessionId: true,
                didIntercept: releaseHeldStarts
            )
        )
        let attributes: [String: AttributeValue] = ["session.id": .string(sessionId)]

        _ = pipeline.export(spans: [SpanDataTestBuilder.build(name: "changed", attributes: attributes)], explicitTimeout: nil)
        #expect(heldSessionIds(of: session) == [replacedSessionId, sessionId])

        // Positive control: an unchanged span of the same session releases its start.
        _ = pipeline.export(spans: [SpanDataTestBuilder.build(name: "kept", attributes: attributes)], explicitTimeout: nil)
        #expect(heldSessionIds(of: session) == [replacedSessionId])
    }


    // MARK: - Helpers

    /// Moves the span named "changed" to `sessionId`; leaves any other span unchanged.
    private static func moveSpanNamedChanged(_ span: SpanData, to sessionId: String) -> SpanData? {
        guard span.name == "changed" else {
            return span
        }

        var span = span
        return span.settingAttributes(span.attributes.merging(["session.id": .string(sessionId)]) { _, new in new })
    }

    /// A session whose first session was rotated into the current one; both starts are held.
    ///
    /// Returns the session and the ID of the replaced session.
    private func makeSessionHoldingTwoStarts() -> (DefaultSession, String) {
        let session = DefaultSession(
            sessionsModel: SessionsModel(storage: UserDefaultsStorageTestBuilder.buildCleanStorage(named: UUID().uuidString))
        )
        session.scheduleSessionStart()
        let replacedSessionId = session.currentSessionId
        session.rotateSession()

        return (session, replacedSessionId)
    }

    /// The IDs of the held starts, oldest first, read after any release queued before it.
    private func heldSessionIds(of session: DefaultSession) -> [String] {
        // `currentSessionId` reads on the session's serial queue, so the releases queued before it have run.
        _ = session.currentSessionId

        return session.pendingSessionStarts.map(\.session.id)
    }
}
