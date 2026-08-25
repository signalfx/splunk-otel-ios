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

final class NetworkSpanFinalizationCoordinatorTests: XCTestCase {

    // MARK: - Tests

    func testConcurrentCallbacksFinalizeExactlyOnceWithRichTaskAttributes() {
        let task = completedTask()
        let span = ThreadSafeMockSpan()
        let coordinator = NetworkSpanFinalizationCoordinator(span: span)
        coordinator.attach(to: task)

        let group = DispatchGroup()
        for index in 0 ..< 100 {
            group.enter()
            DispatchQueue.global()
                .async {
                    if index.isMultiple(of: 2) {
                        coordinator.finalize(task: task)
                    }
                    else {
                        coordinator.finalize(response: task.response, error: task.error)
                    }
                    group.leave()
                }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(span.endCount, 1)

        let attributes = span.attributes
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
    }

    func testCompletionBeforeTaskAttachmentFinalizesAfterAttachment() {
        let task = completedTask()
        let span = ThreadSafeMockSpan()
        let coordinator = NetworkSpanFinalizationCoordinator(span: span)

        coordinator.finalize(response: task.response, error: task.error)
        XCTAssertEqual(span.endCount, 0)

        coordinator.attach(to: task)
        XCTAssertEqual(span.endCount, 1)
        XCTAssertEqual(span.attributes[SemanticConventions.Http.responseStatusCode.rawValue], .int(207))

        coordinator.finalize(task: task)
        XCTAssertEqual(span.endCount, 1)
    }

    func testOnlyCompletedStateTriggersFinalization() {
        XCTAssertFalse(shouldFinalizeNetworkSpan(for: .running))
        XCTAssertFalse(shouldFinalizeNetworkSpan(for: .suspended))
        XCTAssertFalse(shouldFinalizeNetworkSpan(for: .canceling))
        XCTAssertTrue(shouldFinalizeNetworkSpan(for: .completed))
    }


    // MARK: - Helpers

    private func completedTask() -> URLSessionDataTask {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FinalizationURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let completed = expectation(description: "Task completed")
        guard let url = URL(string: "https://finalization.test/resource") else {
            preconditionFailure("Static finalization test URL is invalid")
        }

        let task = session.dataTask(with: url) { _, _, _ in
            completed.fulfill()
        }

        task.resume()
        wait(for: [completed], timeout: 5)

        return task
    }
}

// MARK: - Test URL protocol

private final class FinalizationURLProtocol: URLProtocol {
    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
            let response = HTTPURLResponse(
                url: url,
                statusCode: 207,
                httpVersion: "HTTP/2",
                headerFields: [
                    "Content-Length": "42",
                    "Server": "h2",
                    "Server-Timing": "traceparent;desc='00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-03'",
                    "X-Forwarded-For": "192.0.2.10"
                ]
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(repeating: 0, count: 42))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Thread-safe span

private final class ThreadSafeMockSpan: Span {
    private let lock = NSLock()
    private var storedAttributes: [String: AttributeValue] = [:]
    private var storedEndCount = 0
    private var ended = false

    var attributes: [String: AttributeValue] {
        lock.lock()
        defer { lock.unlock() }
        return storedAttributes
    }

    var endCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedEndCount
    }

    let context = SpanContext.create(
        traceId: .random(),
        spanId: .random(),
        traceFlags: TraceFlags(),
        traceState: TraceState()
    )

    var isRecording: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !ended
    }

    var status: Status = .unset
    var name = "NetworkSpanFinalizationCoordinatorTests"
    var kind: SpanKind {
        .client
    }

    func setAttribute(key: String, value: AttributeValue?) {
        lock.lock()
        defer { lock.unlock() }
        guard !ended else {
            return
        }

        if let value {
            storedAttributes[key] = value
        }
        else {
            storedAttributes.removeValue(forKey: key)
        }
    }

    func setAttributes(_ attributes: [String: AttributeValue]) {
        for (key, value) in attributes {
            setAttribute(key: key, value: value)
        }
    }

    func addEvent(name _: String) {}
    func addEvent(name _: String, timestamp _: Date) {}
    func addEvent(name _: String, attributes _: [String: AttributeValue]) {}
    func addEvent(name _: String, attributes _: [String: AttributeValue], timestamp _: Date) {}

    func end() {
        lock.lock()
        defer { lock.unlock() }
        guard !ended else {
            return
        }

        ended = true
        storedEndCount += 1
    }

    func end(time _: Date) {
        end()
    }

    func recordException(_: SpanException) {}
    func recordException(_: SpanException, timestamp _: Date) {}
    func recordException(_: SpanException, attributes _: [String: AttributeValue]) {}
    func recordException(_: SpanException, attributes _: [String: AttributeValue], timestamp _: Date) {}

    var description: String {
        name
    }
}
