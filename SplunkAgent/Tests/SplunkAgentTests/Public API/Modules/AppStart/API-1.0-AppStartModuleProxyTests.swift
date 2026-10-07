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

@_spi(SplunkInternal) @testable import SplunkAgent
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
        XCTAssertNotNil(
            moduleProxy.track(
                initialLifecycle: SplunkAgent.AppStartLifecycleSnapshot(
                    launchOrigin: .foreground,
                    didFinishLaunching: Date(),
                    willEnterForeground: nil,
                    didBecomeActive: Date()
                )
            )
        )
    }

    func testInitialLifecycleSnapshotIsForwardedToModule() throws {
        let module = try XCTUnwrap(module)
        let moduleProxy = try XCTUnwrap(moduleProxy)
        let destination = DebugDestination()
        let processStart = Date(timeIntervalSinceReferenceDate: 1_000)
        let active = processStart.addingTimeInterval(0.5)
        module.processStartTimestamp = processStart
        module.destination = destination

        moduleProxy.track(
            initialLifecycle: SplunkAgent.AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: nil,
                didBecomeActive: active
            )
        )

        let appStart = try XCTUnwrap(destination.storedAppStart)
        XCTAssertEqual(appStart.type, .cold)
        XCTAssertEqual(appStart.start, processStart)
        XCTAssertEqual(appStart.end, active)
    }
}
