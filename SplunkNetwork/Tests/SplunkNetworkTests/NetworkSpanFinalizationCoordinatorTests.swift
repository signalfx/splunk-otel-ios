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

final class NetworkSpanFinalizationCoordinatorTests: XCTestCase {

    // MARK: - Tests

    func testConcurrentCallbacksFinalizeExactlyOnceWithRichTaskAttributes() {
        let task = completedTask()
        let span = ThreadSafeMockSpan()
        let coordinator = makeCoordinator(span: span)
        coordinator.attach(to: task)
        coordinator.start(task: task)

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
        XCTAssertEqual(span.endInvocationCount, 1)

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
        let coordinator = makeCoordinator(span: span)

        coordinator.start(task: task)
        coordinator.finalize(response: task.response, error: task.error)
        XCTAssertEqual(span.endCount, 0)

        coordinator.attach(to: task)
        XCTAssertEqual(span.endCount, 1)
        XCTAssertEqual(span.attributes[SemanticConventions.Http.responseStatusCode.rawValue], .int(207))

        coordinator.finalize(task: task)
        XCTAssertEqual(span.endCount, 1)
    }

    func testCompletionBeforeResumeDoesNotExportSpan() {
        let task = unstartedTask()
        let span = ThreadSafeMockSpan()
        let coordinator = makeCoordinator(span: span)
        coordinator.attach(to: task)

        coordinator.finalize(response: nil, error: nil)

        XCTAssertEqual(span.endCount, 0)
    }

    func testStartRecordsRequestStartedEventAtProvidedTimestamp() {
        let task = unstartedTask()
        let span = ThreadSafeMockSpan()
        let coordinator = makeCoordinator(span: span)
        let startTime = Date(timeIntervalSince1970: 100)
        coordinator.attach(to: task)

        coordinator.start(task: task, at: startTime)

        XCTAssertEqual(span.events.count, 1)
        XCTAssertEqual(span.events.first?.name, NetworkInstrumentationConstants.requestStartedEventName)
        XCTAssertEqual(span.events.first?.timestamp, startTime)
    }

    func testPreResumeFinalizationDoesNotRetainTask() {
        weak var weakTask: URLSessionDataTask?
        weak var weakCoordinator: NetworkSpanFinalizationCoordinator?

        autoreleasepool {
            let task = unstartedTask()
            let coordinator = makeCoordinator(span: ThreadSafeMockSpan())
            weakTask = task
            weakCoordinator = coordinator

            coordinator.attach(to: task)
            coordinator.finalize(task: task)
        }

        XCTAssertNil(weakTask)
        XCTAssertNil(weakCoordinator)
    }

    func testWatchdogFinalizesWithInstrumentationTimeout() {
        let task = unstartedTask()
        let span = ThreadSafeMockSpan()
        let coordinator = NetworkSpanFinalizationCoordinator(
            span: span,
            watchdogDelay: 0.01,
            watchdogScheduler: NetworkSpanWatchdogScheduler(
                queue: DispatchQueue(label: "NetworkSpanFinalizationCoordinatorTests.watchdog")
            )
        )
        coordinator.attach(to: task)
        coordinator.start(task: task)

        let deadline = Date().addingTimeInterval(1)
        while span.endCount == 0, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }

        XCTAssertEqual(span.endCount, 1)
        XCTAssertEqual(
            span.attributes[SemanticConventions.Error.type.rawValue],
            .string(NetworkSpanFinalizationCoordinator.timeoutErrorType)
        )
        XCTAssertEqual(
            span.attributes[SemanticConventions.Error.message.rawValue],
            .string(NetworkSpanFinalizationCoordinator.timeoutErrorMessage)
        )
        XCTAssertEqual(span.attributes[NetworkSpanAttributeKeys.error], .bool(true))
    }

    func testWatchdogEndsAtConfiguredDeadlineWithoutReadingTask() {
        let task = unstartedTask()
        let span = ThreadSafeMockSpan()
        let coordinator = makeCoordinator(span: span)
        let startTime = Date(timeIntervalSince1970: 100)
        let endTime = Date(timeIntervalSince1970: 105)
        coordinator.attach(to: task)
        coordinator.start(task: task, at: startTime)

        coordinator.finalizeTimeout(at: endTime)

        XCTAssertEqual(span.endCount, 1)
        XCTAssertEqual(span.endInvocationCount, 1)
        XCTAssertEqual(span.endTimes, [endTime])
        XCTAssertEqual(span.attributes[NetworkSpanAttributeKeys.error], .bool(true))
    }

    func testTerminalErrorWinsOverInstrumentationTimeout() {
        let task = unstartedTask()
        let span = ThreadSafeMockSpan()
        let coordinator = makeCoordinator(span: span)
        coordinator.attach(to: task)
        coordinator.start(task: task)
        let error = TestNetworkError()

        coordinator.finalize(response: nil, error: error)
        coordinator.finalizeTimeout(at: Date(timeIntervalSince1970: 105))

        XCTAssertEqual(span.endCount, 1)
        XCTAssertEqual(span.attributes[SemanticConventions.Error.type.rawValue], .string("TestNetworkError"))
        XCTAssertEqual(span.attributes[SemanticConventions.Error.message.rawValue], .string(error.localizedDescription))
    }

    func testTerminalCallbackCancelsWatchdogAndFinalizesOnce() {
        let task = unstartedTask()
        let span = ThreadSafeMockSpan()
        let scheduler = NetworkSpanWatchdogScheduler(
            queue: DispatchQueue(label: "NetworkSpanFinalizationCoordinatorTests.watchdog")
        )
        let coordinator = NetworkSpanFinalizationCoordinator(
            span: span,
            watchdogDelay: 0.05,
            watchdogScheduler: scheduler
        )
        coordinator.attach(to: task)
        coordinator.start(task: task)
        coordinator.finalize(response: nil, error: nil)

        XCTAssertEqual(span.endCount, 1)
        XCTAssertEqual(scheduler.pendingCount, 0)

        let deadline = Date().addingTimeInterval(0.2)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }

        XCTAssertEqual(span.endCount, 1)
        XCTAssertNil(span.attributes[SemanticConventions.Error.type.rawValue])
    }

    func testOnlyCompletedStateTriggersFinalization() {
        XCTAssertFalse(shouldFinalizeNetworkSpan(for: .running))
        XCTAssertFalse(shouldFinalizeNetworkSpan(for: .suspended))
        XCTAssertFalse(shouldFinalizeNetworkSpan(for: .canceling))
        XCTAssertTrue(shouldFinalizeNetworkSpan(for: .completed))
    }

    func testCompletedTaskWithoutResumeSignalUsesCreationStartTime() {
        let task = completedTask()
        let span = ThreadSafeMockSpan()
        let coordinator = makeCoordinator(span: span)
        coordinator.attach(to: task)

        coordinator.finalize(task: task)

        XCTAssertEqual(span.endCount, 1)
        XCTAssertTrue(span.events.isEmpty)
        XCTAssertEqual(
            span.attributes[SemanticConventions.Http.responseStatusCode.rawValue],
            .int(207)
        )
    }

    func testTaskWithoutResumeEvidenceRemainsSuppressed() {
        let task = unstartedTask()
        let span = ThreadSafeMockSpan()
        let coordinator = makeCoordinator(span: span)
        coordinator.attach(to: task)

        coordinator.finalize(task: task)

        XCTAssertEqual(span.endCount, 0)
    }

    func testUploadTaskUsesLongWatchdogDelay() throws {
        let configuration = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: configuration)
        let uploadURL = try XCTUnwrap(URL(string: "https://finalization.test/upload"))
        let request = URLRequest(url: uploadURL)
        let task = session.uploadTask(withStreamedRequest: request)

        XCTAssertEqual(
            NetworkSpanFinalizationCoordinator.watchdogDelay(for: task),
            NetworkSpanFinalizationCoordinator.longLivedWatchdogDelay
        )
    }


    // MARK: - Helpers

    private func makeCoordinator(
        span: Span,
        watchdogDelay: TimeInterval? = nil
    ) -> NetworkSpanFinalizationCoordinator {
        NetworkSpanFinalizationCoordinator(
            span: span,
            watchdogDelay: watchdogDelay,
            watchdogScheduler: NetworkSpanWatchdogScheduler(
                queue: DispatchQueue(label: "NetworkSpanFinalizationCoordinatorTests.watchdog.(UUID().uuidString)")
            )
        )
    }

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

    private func unstartedTask() -> URLSessionDataTask {
        let configuration = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: configuration)
        guard let url = URL(string: "https://finalization.test/resource") else {
            preconditionFailure("Static finalization test URL is invalid")
        }

        return session.dataTask(with: url)
    }

}

// MARK: - Test URL protocol

private struct TestNetworkError: LocalizedError {
    var errorDescription: String? {
        "test terminal error"
    }
}

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
