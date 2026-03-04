//
/*
Copyright 2025 Splunk Inc.

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

@testable import SplunkAgent

final class SessionReplaySamplerTests: XCTestCase {

    // MARK: - Private

    private var mockRandomNumberProvider: MockRandomNumberProvider?


    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()

        mockRandomNumberProvider = MockRandomNumberProvider()
    }

    override func tearDown() {
        mockRandomNumberProvider = nil

        super.tearDown()
    }


    // MARK: - Initialization

    func testInitializationWithProbability() {
        let sampler = SessionReplaySampler(probability: 0.75)

        XCTAssertEqual(sampler.probability, 0.75, "Probability should match the value passed to init.")
        XCTAssertEqual(sampler.lowerBound, 0.0, "Lower bound should be 0.0.")
        XCTAssertEqual(sampler.upperBound, 1.0, "Upper bound should be 1.0.")
    }

    func testInitializationWithProbabilityOne() {
        let sampler = SessionReplaySampler(probability: 1.0)

        XCTAssertEqual(sampler.probability, 1.0, "Probability of 1.0 should be stored as-is (always enabled).")
    }


    // MARK: - Sampling decisions

    func testProbabilityOneAlwaysNotSampledOut() throws {
        let sampler = SessionReplaySampler(probability: 1.0)

        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)
        let decision = sampler.sample(randomNumberProvider: mockRandomNumberProvider)

        XCTAssertEqual(decision, .notSampledOut)
        XCTAssertTrue(mockRandomNumberProvider.nextRandomNumbers.isEmpty, "Random number provider should not be used if probability is 1.0.")
    }

    func testProbabilityZeroAlwaysSampledOut() throws {
        let sampler = SessionReplaySampler(probability: 0.0)

        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)
        let decision = sampler.sample(randomNumberProvider: mockRandomNumberProvider)

        XCTAssertEqual(decision, .sampledOut)
        XCTAssertTrue(mockRandomNumberProvider.nextRandomNumbers.isEmpty, "Random number provider should not be used if probability is 0.0.")
    }

    func testRandomNumberLessThanProbabilityShouldNotSampleOut() throws {
        let sampler = SessionReplaySampler(probability: 0.75)

        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)
        mockRandomNumberProvider.nextRandomNumbers = [0.5]

        let decision = sampler.sample(randomNumberProvider: mockRandomNumberProvider)

        XCTAssertEqual(decision, .notSampledOut)
        XCTAssertEqual(mockRandomNumberProvider.rangesProvided.count, 1)
        XCTAssertEqual(mockRandomNumberProvider.rangesProvided.first, sampler.lowerBound ... sampler.upperBound)
    }

    func testRandomNumberGreaterThanProbabilityShouldSampleOut() throws {
        let sampler = SessionReplaySampler(probability: 0.25)

        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)
        mockRandomNumberProvider.nextRandomNumbers = [0.5]

        let decision = sampler.sample(randomNumberProvider: mockRandomNumberProvider)

        XCTAssertEqual(decision, .sampledOut)
        XCTAssertEqual(mockRandomNumberProvider.rangesProvided.count, 1)
        XCTAssertEqual(mockRandomNumberProvider.rangesProvided.first, sampler.lowerBound ... sampler.upperBound)
    }

    func testRandomNumberEqualToProbabilityShouldNotSampleOut() throws {
        let sampler = SessionReplaySampler(probability: 0.5)

        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)
        mockRandomNumberProvider.nextRandomNumbers = [0.5]

        let decision = sampler.sample(randomNumberProvider: mockRandomNumberProvider)

        XCTAssertEqual(decision, .notSampledOut)
    }


    // MARK: - Edge cases

    func testHalfProbabilityUsesRandomProvider() throws {
        let sampler = SessionReplaySampler(probability: 0.5)

        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)

        // Value below threshold → not sampled out
        mockRandomNumberProvider.nextRandomNumbers = [0.3]
        let decision1 = sampler.sample(randomNumberProvider: mockRandomNumberProvider)
        XCTAssertEqual(decision1, .notSampledOut)

        mockRandomNumberProvider.reset()

        // Value above threshold → sampled out
        mockRandomNumberProvider.nextRandomNumbers = [0.8]
        let decision2 = sampler.sample(randomNumberProvider: mockRandomNumberProvider)
        XCTAssertEqual(decision2, .sampledOut)
    }

    func testVeryLowProbabilitySamplesOut() throws {
        let sampler = SessionReplaySampler(probability: 0.01)

        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)
        mockRandomNumberProvider.nextRandomNumbers = [0.02]

        let decision = sampler.sample(randomNumberProvider: mockRandomNumberProvider)

        XCTAssertEqual(decision, .sampledOut)
    }

    func testVeryHighProbabilityDoesNotSampleOut() throws {
        let sampler = SessionReplaySampler(probability: 0.99)

        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)
        mockRandomNumberProvider.nextRandomNumbers = [0.5]

        let decision = sampler.sample(randomNumberProvider: mockRandomNumberProvider)

        XCTAssertEqual(decision, .notSampledOut)
    }
}
