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
import XCTest

@testable import SplunkNetwork

final class NetworkSpanFinalizationErrorTests: XCTestCase {

    func testCompletedTaskWithNonCancellationErrorWithoutResumeSignalExportsSpan() {
        let completion = expectation(description: "Task failed")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        guard let url = URL(string: "https://finalization.test/failure") else {
            preconditionFailure("Static finalization test URL is invalid")
        }
        let task = session.dataTask(with: url) { _, _, _ in
            completion.fulfill()
        }
        task.resume()
        wait(for: [completion], timeout: 5)

        let span = ThreadSafeMockSpan()
        let coordinator = NetworkSpanFinalizationCoordinator(
            span: span,
            watchdogScheduler: NetworkSpanWatchdogScheduler(
                queue: DispatchQueue(label: "NetworkSpanFinalizationErrorTests.watchdog")
            )
        )
        coordinator.attach(to: task)
        coordinator.finalize(task: task)

        XCTAssertEqual(span.endCount, 1)
        XCTAssertEqual(span.attributes[NetworkSpanAttributeKeys.error], .bool(true))
        session.invalidateAndCancel()
    }
}

private final class FailingURLProtocol: URLProtocol {
    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
    }

    override func stopLoading() {}
}
