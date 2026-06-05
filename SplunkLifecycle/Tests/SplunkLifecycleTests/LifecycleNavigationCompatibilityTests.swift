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

internal import CiscoSwizzling
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
@_spi(SplunkTesting) import SplunkLifecycle
@_spi(SplunkTesting) import SplunkNavigation
import XCTest

final class LifecycleNavigationCompatibilityTests: XCTestCase {

    // MARK: - Compatibility matrix

    func testBothModulesEnabledEmitNavigationAndLifecycleSignals() async {
        let logExpectation = expectation(description: "Lifecycle log exports")
        logExpectation.expectedFulfillmentCount = 2
        let spanExpectation = expectation(description: "Navigation span exports")
        spanExpectation.expectedFulfillmentCount = 2
        let logExporter = CapturingCompatibilityLogExporter(exportExpectation: logExpectation)
        let spanExporter = CapturingCompatibilitySpanExporter(exportExpectation: spanExpectation)
        registerOpenTelemetry(logExporter: logExporter, spanExporter: spanExporter)

        let source = CompatibilityEventSource()
        let provider = CompatibilityEventStreamProvider(source: source)
        let navigation = Navigation.splunkTestingInstance(navigationEventStreamProvider: provider)
        let lifecycle = Lifecycle(lifecycleEventStreamProvider: provider)

        navigation.install(
            with: NavigationConfiguration(isEnabled: true, enableAutomatedTracking: true),
            remoteConfiguration: nil
        )
        lifecycle.install(with: LifecycleConfiguration(), remoteConfiguration: nil)
        await source.waitForNavigationSubscribers(count: 2)

        await source.yieldShowLifecycle(for: "CheckoutViewController")

        await fulfillment(of: [logExpectation, spanExpectation], timeout: 1)

        XCTAssertEqual(logExporter.exportedLogRecords.map { $0.attributes["lifecycle.action"]?.description }, ["view_created", "resumed"])
        XCTAssertTrue(spanExporter.exportedSpans.map(\.name).contains("app.ui.navigation"))
        XCTAssertTrue(spanExporter.exportedSpans.map(\.name).contains("ShowVC"))

        await source.finish()
    }

    func testNavigationDisabledLifecycleEnabledEmitsOnlyLifecycleSignals() async {
        let logExpectation = expectation(description: "Lifecycle log exports")
        logExpectation.expectedFulfillmentCount = 2
        let logExporter = CapturingCompatibilityLogExporter(exportExpectation: logExpectation)
        let spanExporter = CapturingCompatibilitySpanExporter()
        registerOpenTelemetry(logExporter: logExporter, spanExporter: spanExporter)

        let source = CompatibilityEventSource()
        let provider = CompatibilityEventStreamProvider(source: source)
        let navigation = Navigation.splunkTestingInstance(navigationEventStreamProvider: provider)
        let lifecycle = Lifecycle(lifecycleEventStreamProvider: provider)

        navigation.install(
            with: NavigationConfiguration(isEnabled: false, enableAutomatedTracking: true),
            remoteConfiguration: nil
        )
        lifecycle.install(with: LifecycleConfiguration(), remoteConfiguration: nil)
        await source.waitForNavigationSubscribers(count: 1)

        await source.yieldShowLifecycle(for: "CheckoutViewController")

        await fulfillment(of: [logExpectation], timeout: 1)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(logExporter.exportedLogRecords.map { $0.attributes["lifecycle.action"]?.description }, ["view_created", "resumed"])
        XCTAssertEqual(spanExporter.exportedSpans.count, 0)

        await source.finish()
    }

    func testLifecycleDisabledNavigationEnabledEmitsOnlyNavigationSignals() async {
        let spanExpectation = expectation(description: "Navigation span exports")
        spanExpectation.expectedFulfillmentCount = 2
        let logExporter = CapturingCompatibilityLogExporter()
        let spanExporter = CapturingCompatibilitySpanExporter(exportExpectation: spanExpectation)
        registerOpenTelemetry(logExporter: logExporter, spanExporter: spanExporter)

        let source = CompatibilityEventSource()
        let provider = CompatibilityEventStreamProvider(source: source)
        let navigation = Navigation.splunkTestingInstance(navigationEventStreamProvider: provider)
        let lifecycle = Lifecycle(lifecycleEventStreamProvider: provider)

        navigation.install(
            with: NavigationConfiguration(isEnabled: true, enableAutomatedTracking: true),
            remoteConfiguration: nil
        )
        lifecycle.install(
            with: LifecycleConfiguration(isEnabled: false),
            remoteConfiguration: nil
        )
        await source.waitForNavigationSubscribers(count: 1)

        await source.yieldShowLifecycle(for: "CheckoutViewController")

        await fulfillment(of: [spanExpectation], timeout: 1)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(logExporter.exportedLogRecords.count, 0)
        XCTAssertTrue(spanExporter.exportedSpans.map(\.name).contains("app.ui.navigation"))
        XCTAssertTrue(spanExporter.exportedSpans.map(\.name).contains("ShowVC"))

        await source.finish()
    }


    // MARK: - Helpers

    private func registerOpenTelemetry(
        logExporter: CapturingCompatibilityLogExporter,
        spanExporter: CapturingCompatibilitySpanExporter
    ) {
        let loggerProvider = LoggerProviderBuilder()
            .with(
                processors: [
                    SimpleLogRecordProcessor(logRecordExporter: logExporter)
                ]
            )
            .build()
        OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)

        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: SimpleSpanProcessor(spanExporter: spanExporter))
            .build()
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    }
}


// MARK: - Test provider

private struct CompatibilityEventStreamProvider: LifecycleEventStreamProviding, NavigationEventStreamProviding {
    let source: CompatibilityEventSource

    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        await source.makeNavigationStream()
    }

    func presentationStream() async throws -> AsyncStream<any PresentationActionEvent> {
        await source.makePresentationStream()
    }
}

private actor CompatibilityEventSource {
    private var navigationContinuations: [AsyncStream<any NavigationActionEvent>.Continuation] = []
    private var presentationContinuations: [AsyncStream<any PresentationActionEvent>.Continuation] = []

    func makeNavigationStream() -> AsyncStream<any NavigationActionEvent> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: (any NavigationActionEvent).self
        )
        navigationContinuations.append(continuation)

        return stream
    }

    func makePresentationStream() -> AsyncStream<any PresentationActionEvent> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: (any PresentationActionEvent).self
        )
        presentationContinuations.append(continuation)

        return stream
    }

    func waitForNavigationSubscribers(count: Int) async {
        let deadline = Date().addingTimeInterval(1)

        while navigationContinuations.count < count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func yieldShowLifecycle(for controllerTypeName: String) {
        let controllerIdentifier = ObjectIdentifier(NSObject())
        let started = Date(timeIntervalSince1970: 200)
        let appeared = Date(timeIntervalSince1970: 201)

        for continuation in navigationContinuations {
            continuation.yield(
                CompatibilityNavigationActionEvent(
                    timestamp: started,
                    type: .viewDidLoad,
                    controllerTypeName: controllerTypeName,
                    controllerIdentifier: controllerIdentifier
                )
            )
            continuation.yield(
                CompatibilityNavigationActionEvent(
                    timestamp: appeared,
                    type: .viewDidAppear,
                    controllerTypeName: controllerTypeName,
                    controllerIdentifier: controllerIdentifier
                )
            )
        }
    }

    func finish() {
        for continuation in navigationContinuations {
            continuation.finish()
        }
        for continuation in presentationContinuations {
            continuation.finish()
        }
    }
}

private struct CompatibilityNavigationActionEvent: NavigationActionEvent {
    let timestamp: Date
    let type: NavigationActionEventType
    let controllerTypeName: String
    let controllerIdentifier: ObjectIdentifier
    var navigationControllerIdentifier: ObjectIdentifier?
    var viewFrame: CGRect?
}


// MARK: - Exporters

private final class CapturingCompatibilityLogExporter: LogRecordExporter {
    private let exportExpectation: XCTestExpectation?
    private let lock = NSLock()
    private var storedLogRecords: [ReadableLogRecord] = []

    var exportedLogRecords: [ReadableLogRecord] {
        lock.withLock { storedLogRecords }
    }

    init(exportExpectation: XCTestExpectation? = nil) {
        self.exportExpectation = exportExpectation
    }

    func export(logRecords: [ReadableLogRecord], explicitTimeout _: TimeInterval?) -> ExportResult {
        lock.withLock {
            storedLogRecords.append(contentsOf: logRecords)
        }
        for _ in logRecords {
            exportExpectation?.fulfill()
        }

        return .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}

    func forceFlush(explicitTimeout _: TimeInterval?) -> ExportResult {
        .success
    }
}

private final class CapturingCompatibilitySpanExporter: SpanExporter {
    private let exportExpectation: XCTestExpectation?
    private let lock = NSLock()
    private var storedSpans: [SpanData] = []

    var exportedSpans: [SpanData] {
        lock.withLock { storedSpans }
    }

    init(exportExpectation: XCTestExpectation? = nil) {
        self.exportExpectation = exportExpectation
    }

    func export(spans: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        lock.withLock {
            storedSpans.append(contentsOf: spans)
        }
        for _ in spans {
            exportExpectation?.fulfill()
        }

        return .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}
}
