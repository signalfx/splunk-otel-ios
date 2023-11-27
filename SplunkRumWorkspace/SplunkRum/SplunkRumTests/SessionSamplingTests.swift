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
            .debug(enabled: true)
            .globalAttributes(globalAttributes: [:])
            .sessionSamplingRatio(samplingRatio: 0.2)
            .build()

        let provider = OpenTelemetry.instance.tracerProvider as! TracerProviderSdk
        let sampler = provider.getActiveSampler() as! SessionBasedSampler

        XCTAssertTrue(sampler.probability >= 0.0 && sampler.probability <= 1.0)
        XCTAssertEqual(sampler.probability, 0.2)
        resetRUM()
    }

    func testSessionIdValue() throws {
        // The result value is taken from the JS RUM SDK for the given input
        let value = sessionIdValue(sessionId: "c06947ed1f53b1a69be3c6899bc11a3e")
        XCTAssertEqual(value, 3742903036)
    }

    /**Test Sending All Spans**/
    func testSessionBasedSampling100Pct() throws {
        // Forces RUM to reinitialze for testing
        SplunkRum.initialized = false
        _ = SplunkRumBuilder(beaconUrl: "http://127.0.0.1:8989/", rumAuth: "FAKE_RUM_AUTH")
            .allowInsecureBeacon(enabled: true)
            .debug(enabled: true)
            .globalAttributes(globalAttributes: [:])
            .sessionSamplingRatio(samplingRatio: 1.0)
            .build()

        let provider = OpenTelemetry.instance.tracerProvider as! TracerProviderSdk
        let sampler = provider.getActiveSampler() as! SessionBasedSampler
        let shouldSample = sampler.shouldSample(parentContext: nil, traceId: .random(), name: "Span Example", kind: .client, attributes: [:], parentLinks: [])

        XCTAssertTrue(shouldSample.isSampled)
        resetRUM()
    }

    /**Tests Sending 0 Spans**/
    func testSessionBasedSampling0Pct() throws {
        // Forces RUM to reinitialze for testing
        SplunkRum.initialized = false
        _ = SplunkRumBuilder(beaconUrl: "http://127.0.0.1:8989/", rumAuth: "FAKE_RUM_AUTH")
            .allowInsecureBeacon(enabled: true)
            .debug(enabled: true)
            .globalAttributes(globalAttributes: [:])
            .sessionSamplingRatio(samplingRatio: 0.0)
            .build()

        let provider = OpenTelemetry.instance.tracerProvider as! TracerProviderSdk
        let sampler = provider.getActiveSampler() as! SessionBasedSampler
        let shouldSample = sampler.shouldSample(parentContext: nil, traceId: .random(), name: "Span Example", kind: .client, attributes: [:], parentLinks: [])

        XCTAssertFalse(shouldSample.isSampled)
        resetRUM()
    }

    /**Tests 50% we get roughly that amount*/
    func testSessionBasedSampling50Pct() throws {
        // Forces RUM to reinitialze for testing
        SplunkRum.initialized = false
        _ = SplunkRumBuilder(beaconUrl: "http://127.0.0.1:8989/", rumAuth: "FAKE_RUM_AUTH")
            .allowInsecureBeacon(enabled: true)
            .debug(enabled: true)
            .globalAttributes(globalAttributes: [:])
            .sessionSamplingRatio(samplingRatio: 0.5)
            .build()

        let provider = OpenTelemetry.instance.tracerProvider as! TracerProviderSdk
        let sampler = provider.getActiveSampler() as! SessionBasedSampler

        func testSampling() -> Bool {
            _ = getRumSessionId(forceNewSessionId: true)
            let shouldSample = sampler.shouldSample(parentContext: nil, traceId: .random(), name: "Span Example", kind: .client, attributes: [:], parentLinks: [])
            return shouldSample.isSampled
        }

        var countSpans = 0
        for _ in 1...100 where testSampling() {
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
            .debug(enabled: true)
            .globalAttributes(globalAttributes: [:])
            .build()

        print("Sampling Ratio: \(SplunkRum.configuredOptions?.sessionSamplingRatio ?? 0.0)")
    }

}
