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

@_spi(SplunkInternal) import SplunkCommon
import XCTest

@testable import SplunkAgent
@_spi(SplunkInternal) @testable import SplunkAppStart

final class AppStartAPI10ModuleProxyTests: XCTestCase {

    // MARK: - Private

    private var module: SplunkAppStart.AppStart?
    private var moduleProxy: SplunkAgent.AppStart?


    // MARK: - Setup and teardown

    override func setUp() {
        super.setUp()

        module = SplunkAppStart.AppStart()

        if let module {
            moduleProxy = SplunkAgent.AppStart(for: module)
        }
    }

    override func tearDown() {
        super.tearDown()

        module = nil
        moduleProxy = nil
    }


    // MARK: - Manual tracking

    func testManualTracking() throws {
        let moduleProxy = try XCTUnwrap(moduleProxy)

        XCTAssertNotNil(moduleProxy.track(didBecomeActive: Date(), didFinishLaunching: Date(), willEnterForeground: Date()))
        XCTAssertNotNil(moduleProxy.track(didBecomeActive: Date(), didFinishLaunching: nil, willEnterForeground: nil))
    }

    func testInitialLifecycleTrackingForwardsToModule() throws {
        let module = try XCTUnwrap(module)
        let moduleProxy = try XCTUnwrap(moduleProxy)
        let now = Date()
        let destination = DebugDestination()
        module.destination = destination
        module.processStartTimestamp = now.addingTimeInterval(-2.0)

        _ = moduleProxy.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                launchOriginConfidence: .observed,
                didFinishLaunching: now.addingTimeInterval(-1.5),
                willEnterForeground: now.addingTimeInterval(-1.0),
                didBecomeActive: now
            )
        )

        XCTAssertEqual(destination.storedAppStart?.type, .cold)
    }
}
