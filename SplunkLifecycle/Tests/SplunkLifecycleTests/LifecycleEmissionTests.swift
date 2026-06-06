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
@_spi(SplunkInternal) @_spi(SplunkTesting) import SplunkLifecycle
import XCTest

final class LifecycleEmissionTests: XCTestCase {

    // MARK: - Emission

    func testEmitsAllowedLifecycleEventsWithExpectedAttributesAndTimestamps() async {
        let exportExpectation = expectation(description: "Lifecycle log export")
        exportExpectation.expectedFulfillmentCount = 3
        let exporter = CapturingLogRecordExporter(exportExpectation: exportExpectation)
        registerLoggerProvider(exporter: exporter)

        let source = LifecycleEventSource()
        let lifecycle = Lifecycle(
            lifecycleEventStreamProvider: MockLifecycleEventStreamProvider(source: source),
            applicationBundleName: "DemoApp"
        )
        lifecycle.install(with: LifecycleConfiguration(), remoteConfiguration: nil)
        await source.waitForNavigationSubscriber()

        let timestamps = [
            Date(timeIntervalSince1970: 100),
            Date(timeIntervalSince1970: 101),
            Date(timeIntervalSince1970: 102)
        ]

        await source.yieldNavigation(
            MockNavigationActionEvent(
                timestamp: timestamps[0],
                type: .viewDidLoad,
                controllerTypeName: "DemoApp.CheckoutViewController",
                controllerIdentifier: ObjectIdentifier(NSObject())
            )
        )
        await source.yieldNavigation(
            MockNavigationActionEvent(
                timestamp: timestamps[1],
                type: .viewDidAppear,
                controllerTypeName: "DemoApp.CheckoutViewController",
                controllerIdentifier: ObjectIdentifier(NSObject())
            )
        )
        await source.yieldNavigation(
            MockNavigationActionEvent(
                timestamp: timestamps[2],
                type: .viewDidDisappear,
                controllerTypeName: "DemoApp.CheckoutViewController",
                controllerIdentifier: ObjectIdentifier(NSObject())
            )
        )

        await fulfillment(of: [exportExpectation], timeout: 1)

        let records = exporter.exportedLogRecords
        assertLifecycleLogRecords(records, timestamps: timestamps)

        await source.finish()
    }

    func testFiltersDisallowedUnsupportedAndIgnoredControllerEvents() async {
        let exportExpectation = expectation(description: "Only one lifecycle log export")
        let exporter = CapturingLogRecordExporter(exportExpectation: exportExpectation)
        registerLoggerProvider(exporter: exporter)

        let source = LifecycleEventSource()
        let lifecycle = Lifecycle(lifecycleEventStreamProvider: MockLifecycleEventStreamProvider(source: source))
        lifecycle.install(
            with: LifecycleConfiguration(allowedEvents: [.resumed]),
            remoteConfiguration: nil
        )
        await source.waitForNavigationSubscriber()

        await source.yieldNavigation(
            MockNavigationActionEvent(
                timestamp: Date(),
                type: .viewDidLoad,
                controllerTypeName: "CheckoutViewController",
                controllerIdentifier: ObjectIdentifier(NSObject())
            )
        )
        await source.yieldNavigation(
            MockNavigationActionEvent(
                timestamp: Date(),
                type: .viewWillTransition,
                controllerTypeName: "CheckoutViewController",
                controllerIdentifier: ObjectIdentifier(NSObject())
            )
        )
        await source.yieldNavigation(
            MockNavigationActionEvent(
                timestamp: Date(),
                type: .viewDidAppear,
                controllerTypeName: "UINavigationController",
                controllerIdentifier: ObjectIdentifier(NSObject())
            )
        )
        await source.yieldNavigation(
            MockNavigationActionEvent(
                timestamp: Date(),
                type: .viewDidAppear,
                controllerTypeName: "CheckoutViewController",
                controllerIdentifier: ObjectIdentifier(NSObject())
            )
        )

        await fulfillment(of: [exportExpectation], timeout: 1)

        let records = exporter.exportedLogRecords
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].attributes["lifecycle.action"]?.description, "resumed")
        XCTAssertEqual(records[0].attributes["element.name"]?.description, "CheckoutViewController")

        await source.finish()
    }

    func testDisabledConfigurationDoesNotSubscribeOrEmit() async throws {
        let exporter = CapturingLogRecordExporter()
        registerLoggerProvider(exporter: exporter)

        let source = LifecycleEventSource()
        let lifecycle = Lifecycle(lifecycleEventStreamProvider: MockLifecycleEventStreamProvider(source: source))
        lifecycle.install(
            with: LifecycleConfiguration(isEnabled: false),
            remoteConfiguration: nil
        )

        try await Task.sleep(nanoseconds: 50_000_000)

        let navigationSubscriberCount = await source.navigationSubscriberCount

        XCTAssertEqual(navigationSubscriberCount, 0)
        XCTAssertEqual(exporter.exportedLogRecords.count, 0)
    }

    func testEmptyAllowedEventsDoesNotSubscribeOrEmit() async throws {
        let exporter = CapturingLogRecordExporter()
        registerLoggerProvider(exporter: exporter)

        let source = LifecycleEventSource()
        let lifecycle = Lifecycle(lifecycleEventStreamProvider: MockLifecycleEventStreamProvider(source: source))
        lifecycle.install(
            with: LifecycleConfiguration(allowedEvents: []),
            remoteConfiguration: nil
        )

        try await Task.sleep(nanoseconds: 50_000_000)

        let navigationSubscriberCount = await source.navigationSubscriberCount

        XCTAssertEqual(navigationSubscriberCount, 0)
        XCTAssertEqual(exporter.exportedLogRecords.count, 0)
    }

    func testApplicationBundleNameCanBeUpdatedBeforeEmission() async {
        let exportExpectation = expectation(description: "Lifecycle log export")
        let exporter = CapturingLogRecordExporter(exportExpectation: exportExpectation)
        registerLoggerProvider(exporter: exporter)

        let source = LifecycleEventSource()
        let lifecycle = Lifecycle(
            lifecycleEventStreamProvider: MockLifecycleEventStreamProvider(source: source),
            applicationBundleName: nil
        )
        lifecycle.setApplicationBundleName("DemoApp")
        lifecycle.install(with: LifecycleConfiguration(allowedEvents: [.resumed]), remoteConfiguration: nil)
        await source.waitForNavigationSubscriber()

        await source.yieldNavigation(
            MockNavigationActionEvent(
                timestamp: Date(timeIntervalSince1970: 103),
                type: .viewDidAppear,
                controllerTypeName: "DemoApp.CheckoutViewController",
                controllerIdentifier: ObjectIdentifier(NSObject())
            )
        )

        await fulfillment(of: [exportExpectation], timeout: 1)

        let records = exporter.exportedLogRecords
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].attributes["element.name"]?.description, "CheckoutViewController")
        XCTAssertEqual(records[0].attributes["element.id"]?.description, "DemoApp.CheckoutViewController")

        await source.finish()
    }


    // MARK: - Helpers

    private func registerLoggerProvider(exporter: CapturingLogRecordExporter) {
        let loggerProvider = LoggerProviderBuilder()
            .with(
                processors: [
                    SimpleLogRecordProcessor(logRecordExporter: exporter)
                ]
            )
            .build()
        OpenTelemetry.registerLoggerProvider(loggerProvider: loggerProvider)
    }

    private func assertLifecycleLogRecords(
        _ records: [ReadableLogRecord],
        timestamps: [Date]
    ) {
        XCTAssertEqual(records.map(\.timestamp), timestamps)
        XCTAssertEqual(records.map { $0.attributes["event.name"]?.description }, Array(repeating: "app.ui.lifecycle", count: 3))
        XCTAssertEqual(records.map { $0.attributes["component"]?.description }, Array(repeating: "ui", count: 3))
        XCTAssertEqual(records.map { $0.attributes["element.type"]?.description }, Array(repeating: "UIViewController", count: 3))
        XCTAssertEqual(records.map { $0.attributes["element.name"]?.description }, Array(repeating: "CheckoutViewController", count: 3))
        XCTAssertEqual(records.map { $0.attributes["element.id"]?.description }, Array(repeating: "DemoApp.CheckoutViewController", count: 3))
        XCTAssertEqual(
            records.map { $0.attributes["lifecycle.action"]?.description },
            ["view_created", "resumed", "stopped"]
        )
    }
}


// MARK: - Test provider

private struct MockLifecycleEventStreamProvider: LifecycleEventStreamProviding {
    let source: LifecycleEventSource

    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        await source.makeNavigationStream()
    }
}

private actor LifecycleEventSource {
    private var navigationContinuations: [AsyncStream<any NavigationActionEvent>.Continuation] = []

    var navigationSubscriberCount: Int {
        navigationContinuations.count
    }

    func makeNavigationStream() -> AsyncStream<any NavigationActionEvent> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: (any NavigationActionEvent).self
        )
        navigationContinuations.append(continuation)

        return stream
    }

    func waitForNavigationSubscriber() async {
        let deadline = Date().addingTimeInterval(1)

        while navigationContinuations.isEmpty, Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func yieldNavigation(_ event: any NavigationActionEvent) {
        for continuation in navigationContinuations {
            continuation.yield(event)
        }
    }

    func finish() {
        for continuation in navigationContinuations {
            continuation.finish()
        }
    }
}

private struct MockNavigationActionEvent: NavigationActionEvent {
    let timestamp: Date
    let type: NavigationActionEventType
    let controllerTypeName: String
    let controllerIdentifier: ObjectIdentifier
    var navigationControllerIdentifier: ObjectIdentifier?
    var viewFrame: CGRect?
}


// MARK: - Exporter

private final class CapturingLogRecordExporter: LogRecordExporter {
    private let exportExpectation: XCTestExpectation?
    private let lock = NSLock()
    private var storedLogRecords: [ReadableLogRecord] = []

    var exportedLogRecords: [ReadableLogRecord] {
        lock.withLock {
            storedLogRecords
        }
    }

    init(exportExpectation: XCTestExpectation? = nil) {
        self.exportExpectation = exportExpectation
    }

    func export(logRecords: [ReadableLogRecord], explicitTimeout _: TimeInterval?) -> ExportResult {
        lock.withLock {
            storedLogRecords.append(contentsOf: logRecords)
        }
        exportExpectation?.fulfill()

        return .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}

    func forceFlush(explicitTimeout _: TimeInterval?) -> ExportResult {
        .success
    }
}
