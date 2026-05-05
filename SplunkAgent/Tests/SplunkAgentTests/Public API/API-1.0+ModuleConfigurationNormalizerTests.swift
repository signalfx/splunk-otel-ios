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
import SplunkAppStart
import SplunkAppState
import SplunkCustomTracking
import SplunkInteractions
import SplunkNavigation
import SplunkNetwork
import SplunkNetworkMonitor
import SplunkSessionReplayProxy
import SplunkSlowFrameDetector
import SplunkWebView
import XCTest

@testable import SplunkAgent

final class API10ModuleConfigurationNormalizerTests: XCTestCase {

    // MARK: - Tests

    func testNormalizeModuleConfigurationsConvertsWrappersToInternalConcreteTypes() throws {
        let ignoreURLs = try SplunkAgent.IgnoreURLs(patterns: ["api\\.internal\\.com"])
        let input: [Any] = [
            SplunkAgent.NavigationConfiguration(isEnabled: false, enableAutomatedTracking: true),
            SplunkAgent.NetworkInstrumentationConfiguration(
                isEnabled: false,
                ignoreURLs: ignoreURLs,
                injectTraceHeaders: false,
                capturedRequestHeaders: ["x-request"],
                capturedResponseHeaders: ["x-response"]
            ),
            SplunkAgent.NetworkMonitorConfiguration(isEnabled: false),
            SplunkAgent.SlowFrameDetectorConfiguration(isEnabled: false),
            SplunkAgent.SessionReplayConfiguration(enabled: false, samplingRate: 0.25),
            SplunkAgent.InteractionsConfiguration(isEnabled: false),
            SplunkAgent.WebViewInstrumentationConfiguration(),
            SplunkAgent.AppStartConfiguration(),
            SplunkAgent.AppStateConfiguration(),
            SplunkAgent.CustomTrackingConfiguration()
        ]

        let normalized = try XCTUnwrap(SplunkRum.normalizeModuleConfigurations(input))

        XCTAssertTrue(normalized[0] is SplunkNavigation.NavigationConfiguration)
        XCTAssertTrue(normalized[1] is SplunkNetwork.NetworkInstrumentationConfiguration)
        XCTAssertTrue(normalized[2] is SplunkNetworkMonitor.NetworkMonitorConfiguration)
        XCTAssertTrue(normalized[3] is SplunkSlowFrameDetector.SlowFrameDetectorConfiguration)
        XCTAssertTrue(normalized[4] is SplunkSessionReplayProxy.SessionReplayConfiguration)
        XCTAssertTrue(normalized[5] is SplunkInteractions.InteractionsConfiguration)
        XCTAssertTrue(normalized[6] is SplunkWebView.WebViewInstrumentationConfiguration)
        XCTAssertTrue(normalized[7] is SplunkAppStart.AppStartConfiguration)
        XCTAssertTrue(normalized[8] is SplunkAppState.AppStateConfiguration)
        XCTAssertTrue(normalized[9] is SplunkCustomTracking.CustomTrackingConfiguration)

        let navigation = try XCTUnwrap(normalized[0] as? SplunkNavigation.NavigationConfiguration)
        XCTAssertFalse(navigation.isEnabled)
        XCTAssertEqual(navigation.enableAutomatedTracking, true)

        let network = try XCTUnwrap(normalized[1] as? SplunkNetwork.NetworkInstrumentationConfiguration)
        XCTAssertFalse(network.isEnabled)
        XCTAssertFalse(network.injectTraceHeaders)
        XCTAssertEqual(network.capturedRequestHeaders, ["x-request"])
        XCTAssertEqual(network.capturedResponseHeaders, ["x-response"])
        XCTAssertEqual(network.ignoreURLs?.getAllPatterns(), ["api\\.internal\\.com"])

        let sessionReplay = try XCTUnwrap(normalized[4] as? SplunkSessionReplayProxy.SessionReplayConfiguration)
        XCTAssertFalse(sessionReplay.enabled)
        XCTAssertEqual(sessionReplay.samplingRate, 0.25)
    }
}
