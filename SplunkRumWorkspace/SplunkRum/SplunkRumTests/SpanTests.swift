//
/*
Copyright 2021 Splunk Inc.

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
@testable import SplunkOtel

class SpanTests: XCTestCase {
    func testEventSpan() throws {
        // Forces RUM to reinitialze for testing
        SplunkRum.initialized = false
        _ = SplunkRum.initialize(beaconUrl: "http://127.0.0.1:8989/",
                                 rumAuth: "FAKE_RUM_AUTH",
                                 options: SplunkRumOptions(allowInsecureBeacon: true,
                                                           debug: true,
                                                           globalAttributes: [:],
                                                           environment: nil,
                                                           ignoreURLs: nil,
                                                           sessionSamplingRatio: 0.5)
                                 )

        let dictionary: NSDictionary = [
                        "attribute1": "hello",
                        "attribute2": "world!"
        ]
        SplunkRum.reportEvent(name: "testEvent", attributes: dictionary)
    }
}
