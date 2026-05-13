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

@_spi(SplunkInternal) @testable import SplunkNavigation

final class NavigationTrackScreenAttributesTests: XCTestCase {

    private var exporter = CollectingSpanExporter()
    private var originalTracerProvider: TracerProvider = OpenTelemetry.instance.tracerProvider

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

    func testTrackScreenAttributesForwardedToSpan() async {
        let module = Navigation()
        module.preferences = Preferences(enableAutomatedTracking: false)

        module.track(screen: "HomeScreen", attributes: ["section": "main", "tab": "dashboard"])

        XCTAssertEqual(module.currentScreenNameForTesting, "HomeScreen")

        await waitUntil {
            self.exporter.spans.contains { $0.name == "app.ui.navigation" }
        }

        let span = exporter.spans.first { $0.name == "app.ui.navigation" }
        XCTAssertNotNil(span, "Expected an app.ui.navigation span")
        XCTAssertEqual(span?.attributes["screen.name"]?.description, "HomeScreen")
        XCTAssertEqual(span?.attributes["section"]?.description, "main")
        XCTAssertEqual(span?.attributes["tab"]?.description, "dashboard")
    }

    func testSharedStateVersionOnSpan() async {
        let module = Navigation()
        let sharedState = MockNavigationSharedState(agentVersion: "test-agent-version")
        module.sharedState = sharedState

        module.track(screen: "HomeScreen")

        await waitUntil {
            self.navigationSpans.count == 1
        }

        let span = navigationSpans.first
        XCTAssertEqual(span?.instrumentationScope.version, "test-agent-version")
    }

    func testManualSameNameTrackEmitsEveryCallAndPreservesAttributes() async {
        let module = Navigation()

        module.track(screen: "HomeScreen", attributes: ["step": "first"])
        module.track(screen: "HomeScreen", attributes: ["step": "second"])

        await waitUntil {
            self.navigationSpans.count >= 2
        }

        let spans = navigationSpans
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].attributes["screen.name"]?.description, "HomeScreen")
        XCTAssertEqual(spans[0].attributes["last.screen.name"]?.description, "unknown")
        XCTAssertEqual(spans[0].attributes["step"]?.description, "first")
        XCTAssertEqual(spans[1].attributes["screen.name"]?.description, "HomeScreen")
        XCTAssertEqual(spans[1].attributes["last.screen.name"]?.description, "HomeScreen")
        XCTAssertEqual(spans[1].attributes["step"]?.description, "second")
    }

    func testManualTrackDoesNotEmitWhenModuleDisabled() async {
        let module = Navigation()
        let observer = ScreenNameObserverRecorder()
        module.setScreenNameObserver { [observer] name in
            observer.append(name)
        }

        module.install(
            with: NavigationConfiguration(isEnabled: false),
            remoteConfiguration: nil
        )

        module.track(screen: "DisabledScreen", attributes: ["source": "manual"])

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(navigationSpans.isEmpty)
        XCTAssertTrue(observer.values.isEmpty)
        XCTAssertEqual(module.currentScreenNameForTesting, "unknown")
    }

    func testManualTrackPublishesObserverSynchronouslyBeforeReturning() {
        let module = Navigation()
        let observer = ScreenNameObserverRecorder()
        module.setScreenNameObserver { [observer] name in
            observer.append(name)
        }

        module.track(screen: "Checkout")

        XCTAssertEqual(observer.values, ["Checkout"])
        XCTAssertEqual(module.currentScreenNameForTesting, "Checkout")
    }

    func testAutomatedNavigationUsesManualScreenAsLastScreenName() async {
        let fixture = makeNavigationStreamFixture()
        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()
        navigation.track(screen: "ManualScreen")

        let controllerIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 42))

        fixture.sendTransition(
            type: .navigationControllerWillShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: controllerIdentifier,
            controllerTypeName: "DetailViewController"
        )
        fixture.sendTransition(
            type: .navigationControllerDidShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: controllerIdentifier,
            controllerTypeName: "DetailViewController"
        )

        await waitUntil {
            self.navigationSpans.contains { span in
                span.attributes["screen.name"]?.description == "DetailViewController"
            }
        }

        let span = navigationSpans.first { span in
            span.attributes["screen.name"]?.description == "DetailViewController"
        }
        XCTAssertEqual(span?.attributes["last.screen.name"]?.description, "ManualScreen")
    }

    private var navigationSpans: [SpanData] {
        exporter.spans.filter { $0.name == "app.ui.navigation" }
    }
}

private final class ScreenNameObserverRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues: [String] = []

    var values: [String] {
        lock.withLock { storedValues }
    }

    func append(_ value: String) {
        lock.withLock { storedValues.append(value) }
    }
}

private final class MockNavigationSharedState: AgentSharedState, @unchecked Sendable {
    let sessionId = "test-session-id"
    let sessionMetadata: String? = nil
    let agentVersion: String

    init(agentVersion: String) {
        self.agentVersion = agentVersion
    }

    func applicationState(for _: Date) -> String? {
        nil
    }
}
