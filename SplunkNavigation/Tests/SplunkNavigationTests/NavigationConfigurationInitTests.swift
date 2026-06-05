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

@_spi(SplunkTesting) import SplunkNavigation
import XCTest

/// Verifies that ``NavigationConfiguration`` init defaults are consistent
/// with the property-level defaults.
final class NavigationConfigurationInitTests: XCTestCase {

    func testIsEnabledDefaultsToTrueWhenOmittedFromFullInit() {
        let config = NavigationConfiguration(enableAutomatedTracking: true)
        XCTAssertTrue(config.isEnabled)
    }

    func testIsEnabledDefaultsToTrueWhenOnlyProcessorProvided() {
        let config = NavigationConfiguration(navigationEventProcessor: PassthroughProcessor())
        XCTAssertTrue(config.isEnabled)
    }
}


// MARK: - Test fixtures

private struct PassthroughProcessor: NavigationEventProcessor {
    func onViewController(typeName: String, controllerIdentity _: String) -> NavigationEvent? {
        NavigationEvent(name: typeName)
    }
}
