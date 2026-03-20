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

final class AdditionalTaskSwizzlingTests: XCTestCase {
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

    private func waitForSpans(
        count: Int,
        timeout: TimeInterval = 5.0
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Self.exporter.spans.count < count, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    // MARK: - Download Task Completion Handler Tests

    func testDownloadTaskWithRequestAndCompletion_CreatesSpan() throws {
        let url = try XCTUnwrap(URL(string: "https://httpbin.org/get"))
        let request = URLRequest(url: url)

        let expectation = expectation(description: "Download completion called")
        let session = URLSession(configuration: .ephemeral)

        let task = session.downloadTask(with: request) { _, _, _ in
            expectation.fulfill()
        }
        task.resume()

        wait(for: [expectation], timeout: 10.0)
        waitForSpans(count: 1)

        let spans = Self.exporter.spans.filter { $0.name.starts(with: "HTTP") }
        XCTAssertEqual(spans.count, 1, "Exactly one HTTP span should be created for downloadTask(with: URLRequest, completionHandler:)")
    }

    func testDownloadTaskWithURLAndCompletion_CreatesSpan() throws {
        let url = try XCTUnwrap(URL(string: "https://httpbin.org/get"))

        let expectation = expectation(description: "Download completion called")
        let session = URLSession(configuration: .ephemeral)

        let task = session.downloadTask(with: url) { _, _, _ in
            expectation.fulfill()
        }
        task.resume()

        wait(for: [expectation], timeout: 10.0)
        waitForSpans(count: 1)

        let spans = Self.exporter.spans.filter { $0.name.starts(with: "HTTP") }
        XCTAssertEqual(spans.count, 1, "Exactly one HTTP span should be created for downloadTask(with: URL, completionHandler:)")
    }

    func testDownloadTaskWithURLAndCompletion_SingleSpan_WhenHeaderInjectionDisabled() throws {
        reinstallModule(injectTraceHeaders: false)
        addTeardownBlock { self.reinstallModule(injectTraceHeaders: true) }

        let url = try XCTUnwrap(URL(string: "https://httpbin.org/get"))

        let expectation = expectation(description: "Download completion called")
        let session = URLSession(configuration: .ephemeral)

        let task = session.downloadTask(with: url) { _, _, _ in
            expectation.fulfill()
        }
        task.resume()

        wait(for: [expectation], timeout: 10.0)
        waitForSpans(count: 1)

        let spans = Self.exporter.spans.filter { $0.name.starts(with: "HTTP") }
        XCTAssertEqual(spans.count, 1, "Only one span should exist for downloadTask(with: URL, completionHandler:) when header injection is off")
    }

    // MARK: - Streamed Upload Task Tests

    func testUploadTaskWithStreamedRequest_CreatesSpan() throws {
        let url = try XCTUnwrap(URL(string: "https://httpbin.org/post"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let expectation = expectation(description: "Task completed")
        let bodyData = Data("streamed body".utf8)
        let delegate = StreamedUploadDelegate(expectation: expectation, bodyData: bodyData)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)

        let task = session.uploadTask(withStreamedRequest: request)
        task.resume()

        wait(for: [expectation], timeout: 10.0)
        waitForSpans(count: 1)

        let spans = Self.exporter.spans.filter { $0.name.starts(with: "HTTP") }
        XCTAssertEqual(spans.count, 1, "Exactly one HTTP span should be created for uploadTask(withStreamedRequest:)")
    }
}

// MARK: - Streamed Upload Delegate

/// Delegate for streamed upload tasks that provides a body stream and signals completion.
private class StreamedUploadDelegate: NSObject, URLSessionTaskDelegate {
    let expectation: XCTestExpectation
    let bodyData: Data

    init(expectation: XCTestExpectation, bodyData: Data) {
        self.expectation = expectation
        self.bodyData = bodyData
    }

    func urlSession(_: URLSession, task _: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        completionHandler(InputStream(data: bodyData))
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError _: Error?) {
        expectation.fulfill()
    }
}
