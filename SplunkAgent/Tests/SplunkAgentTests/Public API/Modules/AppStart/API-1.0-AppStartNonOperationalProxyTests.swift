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

@_spi(SplunkInternal) import SplunkAppStart
@_spi(SplunkInternal) import SplunkCommon
import XCTest

@testable import SplunkAgent

final class AppStartAPI10NoOpProxyTests: XCTestCase {

    // MARK: - Private

    private var moduleProxy = AppStartNonOperational()


    // MARK: - Manual tracking

    func testManualTracking() {
        XCTAssertNotNil(moduleProxy.track(didBecomeActive: Date(), didFinishLaunching: Date(), willEnterForeground: Date()))
        XCTAssertNotNil(moduleProxy.track(didBecomeActive: Date(), didFinishLaunching: nil, willEnterForeground: nil))
    }

    func testInitialLifecycleTrackingIsNoOp() {
        let now = Date()
        let snapshot = AppStartLifecycleSnapshot(
            launchOrigin: .foreground,
            launchOriginConfidence: .observed,
            didFinishLaunching: now.addingTimeInterval(-1.5),
            willEnterForeground: now.addingTimeInterval(-1.0),
            didBecomeActive: now
        )

        XCTAssertNotNil(moduleProxy.track(initialLifecycle: snapshot))
    }
}
