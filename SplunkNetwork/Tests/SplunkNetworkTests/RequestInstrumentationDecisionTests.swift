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

import SplunkCommon
import XCTest

@testable import SplunkNetwork

final class RequestInstrumentationDecisionTests: XCTestCase {

    func testInstrumentationDecisionWithExistingTraceparentDefersToResume() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/customer-request"))
        var request = URLRequest(url: url)
        request.setValue("00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01", forHTTPHeaderField: "traceparent")

        if case .deferToResume = instrumentationDecision(for: request) {
            return
        }

        XCTFail("Customer requests with existing traceparent should defer to resume-time instrumentation")
    }

    func testInstrumentationDecisionWithInternalSDKMarkedRequestSkipsInstrumentation() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/v1/rum"))
        let request = InternalNetworkRequestMarker.mark(URLRequest(url: url))

        if case .skipInstrumentation = instrumentationDecision(for: request) {
            return
        }

        XCTFail("SDK-internal marked requests should be skipped")
    }
}
