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

@testable import SplunkAppStart

extension AppStartReducerTests {

    // MARK: - Observation gaps

    func testObservationGapDropsActivationWithoutFreshForegroundBoundary() {
        let start = Date(timeIntervalSinceReferenceDate: 5_500)
        let evidence = AppStartReducer.Evidence(
            processStart: start,
            launchOrigin: .unknown,
            didFinishLaunching: nil,
            foregroundBoundary: nil,
            didBecomeActive: nil
        )
        let gap = AppStartReducer.reduce(
            state: .initial(evidence),
            event: .observationGap
        )

        let result = AppStartReducer.reduce(
            state: gap.state,
            event: .didBecomeActive(start.addingTimeInterval(3 * 60 * 60))
        )

        XCTAssertNil(result.action)
        XCTAssertEqual(
            result.state,
            .active(.suppressed(.observationGap))
        )
    }
}
