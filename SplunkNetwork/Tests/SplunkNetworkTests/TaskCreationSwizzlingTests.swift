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
import XCTest

@testable import SplunkNetwork

// MARK: - Span-Collecting Exporter

/// A span exporter that collects finished spans in memory for test assertions.
private class CollectingSpanExporter: SpanExporter {
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

// MARK: - Tests

final class TaskCreationSwizzlingTests: XCTestCase {
    private static let exporter = CollectingSpanExporter()
    private static var originalTracerProvider: TracerProvider?
    private static var networkModule: NetworkInstrumentation?

    override static func setUp() {
        super.setUp()

        originalTracerProvider = OpenTelemetry.instance.tracerProvider

        let processor = SimpleSpanProcessor(spanExporter: exporter)
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .build()
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

        networkModule = NetworkInstrumentation()
        let config = NetworkInstrumentationConfiguration(
            isEnabled: true,
            ignoreURLs: nil,
            injectTraceHeaders: true
        )
        networkModule?.install(with: config, remoteConfiguration: nil)
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

    // MARK: - Helpers

    /// Reinstalls the module with a specific configuration for the duration of a test.
    private func reinstallModule(injectTraceHeaders: Bool) {
        Self.networkModule?.uninstall()

        Self.networkModule = NetworkInstrumentation()
        let config = NetworkInstrumentationConfiguration(
            isEnabled: true,
            ignoreURLs: nil,
            injectTraceHeaders: injectTraceHeaders
        )
        Self.networkModule?.install(with: config, remoteConfiguration: nil)
    }

    /// Waits for the exporter to collect the expected number of spans.
    private func waitForSpans(
        count: Int,
        timeout: TimeInterval = 5.0
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Self.exporter.spans.count < count, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    // MARK: - Upload Task Completion Handler Tests

    func testUploadTaskWithDataAndCompletion_CreatesSpan() {
        let url = URLSessionMockProtocol.url(path: "/post")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let data = Data("test body".utf8)

        let expectation = expectation(description: "Upload completion called")
        let session = URLSession(configuration: URLSessionMockProtocol.configuration())

        let task = session.uploadTask(with: request, from: data) { _, _, _ in
            expectation.fulfill()
        }
        task.resume()

        wait(for: [expectation], timeout: 10.0)
        waitForSpans(count: 1)

        let spans = Self.exporter.spans.filter { $0.name.starts(with: "HTTP") }
        XCTAssertEqual(spans.count, 1, "Exactly one HTTP span should be created for uploadTask(with:from:completionHandler:)")
    }

    func testUploadTaskWithFileAndCompletion_CreatesSpan() throws {
        let url = URLSessionMockProtocol.url(path: "/post")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Create a temporary file to upload
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test-upload-\(UUID().uuidString).txt")
        try "test file content".write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let expectation = expectation(description: "Upload completion called")
        let session = URLSession(configuration: URLSessionMockProtocol.configuration())

        let task = session.uploadTask(with: request, fromFile: fileURL) { _, _, _ in
            expectation.fulfill()
        }
        task.resume()

        wait(for: [expectation], timeout: 10.0)
        waitForSpans(count: 1)

        let spans = Self.exporter.spans.filter { $0.name.starts(with: "HTTP") }
        XCTAssertEqual(spans.count, 1, "Exactly one HTTP span should be created for uploadTask(with:fromFile:completionHandler:)")
    }

    func testUploadTaskWithDataAndCompletion_CompletionReceivesData() {
        let url = URLSessionMockProtocol.url(path: "/post")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let data = Data("test body".utf8)

        let expectation = expectation(description: "Upload completion called")
        var receivedData: Data?
        var receivedResponse: URLResponse?
        let session = URLSession(configuration: URLSessionMockProtocol.configuration())

        let task = session.uploadTask(with: request, from: data) { data, response, _ in
            receivedData = data
            receivedResponse = response
            expectation.fulfill()
        }
        task.resume()

        wait(for: [expectation], timeout: 10.0)

        XCTAssertNotNil(receivedResponse, "Completion handler should receive a response")
        XCTAssertNotNil(receivedData, "Completion handler should receive data")
    }

    // MARK: - Single-Span Lifecycle: injectTraceHeaders = false, URL Overloads

    func testDataTaskWithURL_SingleSpan_WhenHeaderInjectionDisabled() {
        reinstallModule(injectTraceHeaders: false)
        addTeardownBlock { self.reinstallModule(injectTraceHeaders: true) }

        let url = URLSessionMockProtocol.url()

        let expectation = expectation(description: "Task completed")
        let delegate = TaskCompletionDelegate(expectation: expectation)
        let delegateSession = URLSession(
            configuration: URLSessionMockProtocol.configuration(),
            delegate: delegate,
            delegateQueue: nil
        )

        let task = delegateSession.dataTask(with: url)
        task.resume()

        wait(for: [expectation], timeout: 10.0)
        waitForSpans(count: 1)

        let spans = Self.exporter.spans.filter { $0.name.starts(with: "HTTP") }
        XCTAssertEqual(spans.count, 1, "Only one span should exist for dataTask(with: URL) when header injection is off")
    }

    func testDataTaskWithURLAndCompletion_SingleSpan_WhenHeaderInjectionDisabled() {
        reinstallModule(injectTraceHeaders: false)
        addTeardownBlock { self.reinstallModule(injectTraceHeaders: true) }

        let url = URLSessionMockProtocol.url()

        let expectation = expectation(description: "Completion called")
        let session = URLSession(configuration: URLSessionMockProtocol.configuration())

        let task = session.dataTask(with: url) { _, _, _ in
            expectation.fulfill()
        }
        task.resume()

        wait(for: [expectation], timeout: 10.0)
        waitForSpans(count: 1)

        let spans = Self.exporter.spans.filter { $0.name.starts(with: "HTTP") }
        XCTAssertEqual(spans.count, 1, "Only one span should exist for dataTask(with: URL, completionHandler:) when header injection is off")
    }

    func testDownloadTaskWithURL_SingleSpan_WhenHeaderInjectionDisabled() {
        reinstallModule(injectTraceHeaders: false)
        addTeardownBlock { self.reinstallModule(injectTraceHeaders: true) }

        let url = URLSessionMockProtocol.url()

        let expectation = expectation(description: "Task completed")
        let delegate = TaskCompletionDelegate(expectation: expectation)
        let delegateSession = URLSession(
            configuration: URLSessionMockProtocol.configuration(),
            delegate: delegate,
            delegateQueue: nil
        )

        let task = delegateSession.downloadTask(with: url)
        task.resume()

        wait(for: [expectation], timeout: 10.0)
        waitForSpans(count: 1)

        let spans = Self.exporter.spans.filter { $0.name.starts(with: "HTTP") }
        XCTAssertEqual(spans.count, 1, "Only one span should exist for downloadTask(with: URL) when header injection is off")
    }

    // MARK: - Resume Event Timing

    func testDataTaskWithRequest_HasResumeEvent() throws {
        let url = URLSessionMockProtocol.url()
        let request = URLRequest(url: url)

        let expectation = expectation(description: "Completion called")
        let session = URLSession(configuration: URLSessionMockProtocol.configuration())

        let task = session.dataTask(with: request) { _, _, _ in
            expectation.fulfill()
        }
        task.resume()

        wait(for: [expectation], timeout: 10.0)
        waitForSpans(count: 1)

        let spans = Self.exporter.spans.filter { $0.name.starts(with: "HTTP") }
        XCTAssertEqual(spans.count, 1)

        let span = try XCTUnwrap(spans.first)
        let resumeEvent = span.events.first { $0.name == "http.request.started" }
        XCTAssertNotNil(resumeEvent, "Creation-instrumented span should contain an http.request.started event recorded at resume")
        if let resumeEvent {
            XCTAssertTrue(resumeEvent.timestamp >= span.startTime, "Resume event should be at or after span start (creation) time")
        }
    }

    // MARK: - Verify Header Injection On vs Off

    func testDataTaskWithURL_HasTraceparent_WhenHeaderInjectionEnabled() throws {
        reinstallModule(injectTraceHeaders: true)

        let url = URLSessionMockProtocol.url(path: "/headers")

        let expectation = expectation(description: "Completion called")
        var responseBody: Data?
        let session = URLSession(configuration: URLSessionMockProtocol.configuration())

        let task = session.dataTask(with: url) { data, _, _ in
            responseBody = data
            expectation.fulfill()
        }
        task.resume()

        wait(for: [expectation], timeout: 10.0)

        let body = try XCTUnwrap(responseBody, "Mock protocol should return a response body")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let headers = try XCTUnwrap(json["headers"] as? [String: Any])
        let traceparent = headers["Traceparent"] ?? headers["traceparent"]
        XCTAssertNotNil(traceparent, "traceparent should be present when injection is enabled")
    }

    func testDataTaskWithURL_NoTraceparent_WhenHeaderInjectionDisabled() throws {
        reinstallModule(injectTraceHeaders: false)
        addTeardownBlock { self.reinstallModule(injectTraceHeaders: true) }

        let url = URLSessionMockProtocol.url(path: "/headers")

        let expectation = expectation(description: "Completion called")
        var responseBody: Data?
        let session = URLSession(configuration: URLSessionMockProtocol.configuration())

        let task = session.dataTask(with: url) { data, _, _ in
            responseBody = data
            expectation.fulfill()
        }
        task.resume()

        wait(for: [expectation], timeout: 10.0)

        let body = try XCTUnwrap(responseBody, "Mock protocol should return a response body")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let headers = try XCTUnwrap(json["headers"] as? [String: Any])
        XCTAssertNil(headers["Traceparent"], "traceparent should not be present when disabled")
        XCTAssertNil(headers["traceparent"], "traceparent should not be present when disabled")
    }
}

// MARK: - Task Completion Delegate

/// Delegate that fulfills an expectation when a task completes (for non-completion-handler APIs).
private class TaskCompletionDelegate: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate {
    let expectation: XCTestExpectation

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError _: Error?) {
        expectation.fulfill()
    }

    func urlSession(_: URLSession, downloadTask _: URLSessionDownloadTask, didFinishDownloadingTo _: URL) {}
}
