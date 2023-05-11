//
/*
Copyright 2023 Splunk Inc.

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

class SessionSamplingTests: XCTestCase {

    func testSessionBasedSamplingInitialization() throws {
        // Forces RUM to reinitialze for testing
        SplunkRum.initialized = false
        _ = SplunkRumBuilder(beaconUrl: "http://127.0.0.1:8989/", rumAuth: "FAKE_RUM_AUTH")
            .allowInsecureBeacon(enabled: true)
            .debugEnabled(enabled: true)
            .globalAttributes(globalAttributes: [:])
            .sessionSamplingRatio(samplingRatio: 0.2)
            .build()
        XCTAssertTrue(SessionBasedSampler.probability >= 0.0 && SessionBasedSampler.probability <= 1.0)
        XCTAssertEqual(SessionBasedSampler.probability, 0.2)
        resetRUM()
    }

    /**Test Sending All Spans**/
    func testSessionBasedSampling100Pct() throws {
        // Forces RUM to reinitialze for testing
        SplunkRum.initialized = false
        _ = SplunkRumBuilder(beaconUrl: "http://127.0.0.1:8989/", rumAuth: "FAKE_RUM_AUTH")
            .allowInsecureBeacon(enabled: true)
            .debugEnabled(enabled: true)
            .globalAttributes(globalAttributes: [:])
            .sessionSamplingRatio(samplingRatio: 1.0)
            .build()
        let shouldSample = SessionBasedSampler.sessionShouldSample()
        XCTAssertTrue(shouldSample)
        resetRUM()
    }

    /**Tests Sending 0 Spans**/
    func testSessionBasedSampling0Pct() throws {
        // Forces RUM to reinitialze for testing
        SplunkRum.initialized = false
        _ = SplunkRumBuilder(beaconUrl: "http://127.0.0.1:8989/", rumAuth: "FAKE_RUM_AUTH")
            .allowInsecureBeacon(enabled: true)
            .debugEnabled(enabled: true)
            .globalAttributes(globalAttributes: [:])
            .sessionSamplingRatio(samplingRatio: 0.0)
            .build()
        let shouldSample = SessionBasedSampler.sessionShouldSample()
        XCTAssertFalse(shouldSample)
        resetRUM()
    }

    /**Tests 50% we get roughly that amount*/
    func testSessionBasedSampling50Pct() throws {
        // Forces RUM to reinitialze for testing
        SplunkRum.initialized = false
        _ = SplunkRumBuilder(beaconUrl: "http://127.0.0.1:8989/", rumAuth: "FAKE_RUM_AUTH")
            .allowInsecureBeacon(enabled: true)
            .debugEnabled(enabled: true)
            .globalAttributes(globalAttributes: [:])
            .sessionSamplingRatio(samplingRatio: 0.5)
            .build()
        var countSpans = 0
        for _ in 1...100 where SessionBasedSampler.sessionShouldSample() {
            countSpans += 1
        }

        let isInTargetRange = countSpans >= 40 && countSpans <= 60
        XCTAssertTrue(isInTargetRange)
        resetRUM()
    }

    /**Needed to reset RUM to the defaults after sampling tests so other tests succeed.*/
    private func resetRUM() {
        SplunkRum.initialized = false
        _ = SplunkRumBuilder(beaconUrl: "http://127.0.0.1:8989/", rumAuth: "FAKE_RUM_AUTH")
            .allowInsecureBeacon(enabled: true)
            .debugEnabled(enabled: true)
            .globalAttributes(globalAttributes: [:])
            .build()

        print("Sampling Ratio: \(SplunkRum.configuredOptions?.sessionSamplingRatio ?? 0.0)")
    }

}
