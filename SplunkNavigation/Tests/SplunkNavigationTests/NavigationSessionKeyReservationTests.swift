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
@_spi(SplunkTesting) import SplunkCommon
import XCTest

@testable import SplunkNavigation

/// Checks that an app cannot set `session.id` or `session.previous_id` on a navigation span.
///
/// Only the agent sets the session attributes. A value from the app would replace the agent's session
/// or give a span tracked with no session an ID that passes the session policy.
final class NavigationSessionKeyReservationTests: XCTestCase {

    // MARK: - Static constants

    private static let callerSessionId = "0123456789abcdef0123456789abcdef"

    private static let callerAttributes: [String: Any] = [
        "session.id": callerSessionId,
        "session.previous_id": callerSessionId,
        "section": "main"
    ]


    // MARK: - Properties

    private var exporter = CollectingSpanExporter()
    private var originalTracerProvider: TracerProvider = OpenTelemetry.instance.tracerProvider


    // MARK: - Setup

    override func setUp() {
        super.setUp()

        exporter = CollectingSpanExporter()
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: SimpleSpanProcessor(spanExporter: exporter))
            .build()
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    }

    override func tearDown() {
        OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)
        super.tearDown()
    }


    // MARK: - Tests

    func testSessionKeysAreReserved() {
        for key in SessionAttributeKeys.agentOnly {
            XCTAssertTrue(Navigation.screenStateReservedAttributeKeys.contains(key), "\(key) is not reserved")
        }
    }

    /// `track(screen:attributes:)` drops the session keys and keeps the other attributes.
    func testTrackScreenDropsSessionKeys() async throws {
        let navigation = Navigation()
        navigation.preferences = Preferences(enableAutomatedTracking: false)

        navigation.track(screen: "CallerIdScreen", attributes: Self.callerAttributes)

        let firstSpan = await firstNavigationSpan()
        let span = try XCTUnwrap(firstSpan)
        XCTAssertNil(span.attributes["session.id"], "The caller's session.id reached the navigation span")
        XCTAssertNil(span.attributes["session.previous_id"], "The caller's session.previous_id reached the navigation span")
        XCTAssertEqual(span.attributes["section"]?.description, "main")
    }

    /// The stored screen state does not keep the session keys.
    func testStoredStateDropsSessionKeys() {
        let navigation = Navigation()

        let attributes = navigation.effectiveCustomAttributes(from: Self.callerAttributes)

        XCTAssertNil(attributes["session.id"])
        XCTAssertNil(attributes["session.previous_id"])
        XCTAssertEqual(attributes["section"]?.description, "main")
    }

    /// Attributes from a `NavigationEventProcessor` lose the session keys; the other attributes stay.
    func testProcessorDropsSessionKeys() async throws {
        let fixture = makeNavigationStreamFixture(
            navigationEventProcessor: SequenceNavigationEventProcessor(
                events: [NavigationEvent(name: "ProcessorScreen", attributes: Self.callerAttributes)]
            )
        )
        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        fixture.showController(
            navigationControllerIdentifier: ObjectIdentifier(NSString()),
            controllerIdentifier: ObjectIdentifier(NSString()),
            controllerTypeName: "GenericViewController"
        )

        let firstSpan = await firstNavigationSpan()
        let span = try XCTUnwrap(firstSpan)
        XCTAssertEqual(span.attributes["navigation.name"]?.description, "ProcessorScreen")
        XCTAssertNil(span.attributes["session.id"], "The processor's session.id reached the navigation span")
        XCTAssertNil(span.attributes["session.previous_id"], "The processor's session.previous_id reached the navigation span")
        XCTAssertEqual(span.attributes["section"]?.description, "main")
    }


    // MARK: - Helpers

    private func firstNavigationSpan() async -> SpanData? {
        await waitUntil {
            !self.navigationSpans.isEmpty
        }

        return navigationSpans.first
    }

    private var navigationSpans: [SpanData] {
        exporter.spans.filter { $0.name == "app.ui.navigation" }
    }
}
