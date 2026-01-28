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

final class DefaultAgentSessionSamplerTests: XCTestCase {

    // MARK: - Private

    private var sampler: DefaultAgentSessionSampler?
    private var mockRandomNumberProvider: MockRandomNumberProvider?


    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()

        sampler = DefaultAgentSessionSampler()
        mockRandomNumberProvider = MockRandomNumberProvider()
    }

    override func tearDown() {
        sampler = nil
        mockRandomNumberProvider = nil

        super.tearDown()
    }


    // MARK: - Basic logic

    func testInitialProbability() throws {
        let sampler = try XCTUnwrap(sampler)

        XCTAssertEqual(sampler.probability, 1.0, "Default probability should be 1.0 (always sample).")
        XCTAssertEqual(sampler.lowerBound, 0.0, "Default lowerBound should be 0.0.")
        XCTAssertEqual(sampler.upperBound, 1.0, "Default upperBound should be 1.0.")
    }

    func testConfigureUpdatesProbability() throws {
        let sampler = try XCTUnwrap(sampler)
        let newSamplingRate = 0.5

        var configuration = try ConfigurationTestBuilder.buildDefault()
        configuration.session.samplingRate = newSamplingRate

        sampler.configure(with: configuration)

        XCTAssertEqual(sampler.probability, newSamplingRate, "Probability should be updated by configure().")
    }


    func testSample_givenNotSamplesOut() throws {
        let sampler = try XCTUnwrap(sampler)
        sampler.probability = 1.0

        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)
        let decision = sampler.sample(randomNumberProvider: mockRandomNumberProvider)

        XCTAssertEqual(decision, .notSampledOut)
        XCTAssertTrue(mockRandomNumberProvider.nextRandomNumbers.isEmpty, "Random number provider should not be used if probability is 1.0")
    }

    func testSample_givenSamplesOut() throws {
        let sampler = try XCTUnwrap(sampler)
        sampler.probability = 0.0

        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)
        let decision = sampler.sample(randomNumberProvider: mockRandomNumberProvider)

        XCTAssertEqual(decision, .sampledOut)
        XCTAssertTrue(mockRandomNumberProvider.nextRandomNumbers.isEmpty, "Random number provider should not be used if probability is 0.0")
    }

    func testSample_givenRandomNumberLessThanOrEqualToProbability_shouldSample() throws {
        let sampler = try XCTUnwrap(sampler)
        sampler.probability = 0.75

        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)
        mockRandomNumberProvider.nextRandomNumbers = [0.5]

        let decision = sampler.sample(randomNumberProvider: mockRandomNumberProvider)

        XCTAssertEqual(decision, .notSampledOut)
        XCTAssertEqual(mockRandomNumberProvider.rangesProvided.count, 1)
        XCTAssertEqual(mockRandomNumberProvider.rangesProvided.first, sampler.lowerBound ... sampler.upperBound)
    }

    func testSample_givenRandomNumberGreaterThanProbability_shouldNotSampleOut() throws {
        let sampler = try XCTUnwrap(sampler)
        sampler.probability = 0.25

        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)
        mockRandomNumberProvider.nextRandomNumbers = [0.5]

        let decision = sampler.sample(randomNumberProvider: mockRandomNumberProvider)

        XCTAssertEqual(decision, .sampledOut)
        XCTAssertEqual(mockRandomNumberProvider.rangesProvided.count, 1)
        XCTAssertEqual(mockRandomNumberProvider.rangesProvided.first, sampler.lowerBound ... sampler.upperBound)
    }

    func testSample_givenRandomNumberEqualToProbability_shouldSample() throws {
        let sampler = try XCTUnwrap(sampler)
        sampler.probability = 0.5

        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)
        mockRandomNumberProvider.nextRandomNumbers = [0.5]

        let decision = sampler.sample(randomNumberProvider: mockRandomNumberProvider)

        XCTAssertEqual(decision, .notSampledOut)
    }

    func testSample_lowerBoundGreaterThanUpperBound_samplesOut() throws {
        // This sanity tests the guard condition added in StatisticalSampler extension
        class MisconfiguredSampler: StatisticalSampler {
            let probability: Double = 0.5
            let upperBound: Double = 0.0
            let lowerBound: Double = 1.0
        }

        let misconfiguredSampler = MisconfiguredSampler()
        let mockRandomNumberProvider = try XCTUnwrap(mockRandomNumberProvider)
        let decision = misconfiguredSampler.sample(randomNumberProvider: mockRandomNumberProvider)

        XCTAssertEqual(decision, .sampledOut)
        XCTAssertTrue(mockRandomNumberProvider.nextRandomNumbers.isEmpty, "Random number provider should not be used if misconfigured.")
    }
}
