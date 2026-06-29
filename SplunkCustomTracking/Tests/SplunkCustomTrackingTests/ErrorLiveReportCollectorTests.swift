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

import XCTest

@testable import SplunkCustomTracking

#if canImport(CrashReporter)

    final class ErrorLiveReportCollectorTests: XCTestCase {

        // MARK: - Diagnostics

        func testDiagnosticsCompletesEmptyWhenDocumentsDirectoryUnavailable() throws {
            let collector = ErrorLiveReportCollector(documentsDirectoryProvider: { nil })
            let expectation = expectation(description: "Diagnostics should complete")
            let stacktrace = Stacktrace(frames: ["0 Test 0x0000000000000001 symbol + 0"])
            var diagnostics: ErrorDiagnostics?

            collector.diagnostics(
                for: stacktrace,
                includeBinaryImages: true
            ) { result in
                diagnostics = result
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 1.0)

            let result = try XCTUnwrap(diagnostics)
            XCTAssertNil(result.processPath)
            XCTAssertNil(result.exceptionThreadsJSON)
            XCTAssertNil(result.exceptionImagesJSON)
        }
    }

#endif
