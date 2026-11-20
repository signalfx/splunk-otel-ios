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
import SplunkCommon
import XCTest

@testable import SplunkNetwork
@testable import SplunkOpenTelemetry

final class NetworkSpanFinalizationIntegrationTests: XCTestCase {

    // MARK: - Test lifecycle

    private static let exporter = FinalizationCollectingSpanExporter()
    private static var networkModule: NetworkInstrumentation?
    private static var originalTracerProvider: TracerProvider?

    override static func setUp() {
        super.setUp()

        originalTracerProvider = OpenTelemetry.instance.tracerProvider

        let processor = SimpleSpanProcessor(
            spanExporter: SpanInterceptorExporter(with: nil, proxy: exporter)
        )
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .build()
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

        networkModule = NetworkInstrumentation()
        let configuration = NetworkInstrumentationConfiguration(
            isEnabled: true,
            ignoreURLs: nil,
            injectTraceHeaders: false,
            capturedResponseHeaders: ["X-Finalization-Test"]
        )
        networkModule?.install(with: configuration, remoteConfiguration: nil)
    }

    override static func tearDown() {
        networkModule?.uninstall()
        networkModule = nil

        if let originalTracerProvider {
            OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)
        }

        super.tearDown()
    }

    override func setUp() {
        super.setUp()
        Self.exporter.reset()
    }


    // MARK: - Tests

    func testDataTaskWithCompletionExportsOneFullyEnrichedSpan() throws {
        let url = URLSessionMockProtocol.url(path: "/finalization")
        let expectation = expectation(description: "Completion called")
        let session = URLSession(configuration: URLSessionMockProtocol.configuration())

        let task = session.dataTask(with: url) { _, _, _ in
            expectation.fulfill()
        }
        task.resume()

        wait(for: [expectation], timeout: 10.0)
        waitForTaskCompletion(task)
        XCTAssertEqual(task.state, .completed)
        waitForSpans(count: 1)

        let spans = Self.exporter.spans.filter {
            $0.attributes[SemanticConventions.Url.full.rawValue] == .string(url.absoluteString)
        }
        XCTAssertEqual(spans.count, 1, "The state and completion callbacks must finalize exactly one span")

        let attributes = try XCTUnwrap(spans.first?.attributes)
        let requestStartedEvent = try XCTUnwrap(
            spans.first?.events.first { $0.name == NetworkInstrumentationConstants.requestStartedEventName }
        )
        XCTAssertEqual(spans.first?.startTime, requestStartedEvent.timestamp)
        XCTAssertEqual(attributes[SemanticConventions.Http.requestMethod.rawValue], .string("GET"))
        XCTAssertEqual(attributes[SemanticConventions.Http.responseStatusCode.rawValue], .int(207))
        XCTAssertEqual(attributes[SemanticConventions.Http.responseBodySize.rawValue], .int(42))
        XCTAssertEqual(attributes[SemanticConventions.Network.peerAddress.rawValue], .string("192.0.2.10"))
        XCTAssertEqual(attributes[SemanticConventions.Network.protocolVersion.rawValue], .string("2"))
        XCTAssertEqual(
            attributes[NetworkSpanAttributeKeys.linkTraceId],
            .string("0af7651916cd43dd8448eb211c80319c")
        )
        XCTAssertEqual(
            attributes[NetworkSpanAttributeKeys.linkSpanId],
            .string("b7ad6b7169203331")
        )
        XCTAssertEqual(
            attributes[NetworkSpanAttributeKeys.responseHeader("x-finalization-test")],
            .string("preserved")
        )
    }

    func testNeverResumedTaskDoesNotExportSpan() {
        let url = URLSessionMockProtocol.url(path: "/never-resumed")
        let session = URLSession(configuration: URLSessionMockProtocol.configuration())
        let task = session.dataTask(with: url)

        task.cancel()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        XCTAssertTrue(Self.exporter.spans.isEmpty)
        session.invalidateAndCancel()
    }

    func testHangingTaskExportsInstrumentationTimeout() throws {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [HangingURLProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)
        let task = session.dataTask(with: URLSessionMockProtocol.url(path: "/hang"))
        let span = try XCTUnwrap(getCreationSpan(for: task))
        let scheduler = NetworkSpanWatchdogScheduler(
            queue: DispatchQueue(label: "NetworkSpanFinalizationIntegrationTests.watchdog")
        )
        let coordinator = NetworkSpanFinalizationCoordinator(
            span: span,
            watchdogDelay: 0.05,
            watchdogScheduler: scheduler
        )
        setSpanFinalizationCoordinator(coordinator, for: task)

        task.resume()
        waitForSpans(count: 1)

        let timeoutSpan = try XCTUnwrap(Self.exporter.spans.first)
        XCTAssertEqual(
            timeoutSpan.attributes[SemanticConventions.Error.type.rawValue],
            .string(NetworkSpanFinalizationCoordinator.timeoutErrorType)
        )
        XCTAssertEqual(
            timeoutSpan.attributes[SemanticConventions.Error.message.rawValue],
            .string(NetworkSpanFinalizationCoordinator.timeoutErrorMessage)
        )
        XCTAssertEqual(
            timeoutSpan.startTime,
            try XCTUnwrap(timeoutSpan.events.first { $0.name == NetworkInstrumentationConstants.requestStartedEventName }).timestamp
        )
        XCTAssertLessThan(timeoutSpan.endTime.timeIntervalSince(timeoutSpan.startTime), 1)

        task.cancel()
        session.invalidateAndCancel()
    }


    // MARK: - Waiting

    private func waitForSpans(count: Int, timeout: TimeInterval = 5.0) {
        let deadline = Date().addingTimeInterval(timeout)
        while Self.exporter.spans.count < count, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func waitForTaskCompletion(_ task: URLSessionTask, timeout: TimeInterval = 5.0) {
        let deadline = Date().addingTimeInterval(timeout)
        while task.state != .completed, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }
}

private final class HangingURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host == URLSessionMockProtocol.host
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {}

    override func stopLoading() {}
}

// MARK: - Span exporter

private final class FinalizationCollectingSpanExporter: SpanExporter {
    private let lock = NSLock()
    private var collectedSpans: [SpanData] = []

    var spans: [SpanData] {
        lock.lock()
        defer { lock.unlock() }
        return collectedSpans
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        collectedSpans.removeAll()
    }

    func export(spans: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        lock.lock()
        defer { lock.unlock() }
        collectedSpans.append(contentsOf: spans)
        return .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}
}
