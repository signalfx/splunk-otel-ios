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
import XCTest

@testable import SplunkCrashReports

final class CrashReportsRemoteConfigurationTests: XCTestCase {

    // MARK: - Valid JSON

    func testValidJSONWithEnabledTrue() throws {
        let json = """
        {
            "configuration": {
                "mrum": {
                    "crashReporting": {
                        "enabled": true
                    }
                }
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let config = try XCTUnwrap(CrashReportsRemoteConfiguration(from: data))

        XCTAssertTrue(config.enabled)
    }

    func testValidJSONWithEnabledFalse() throws {
        let json = """
        {
            "configuration": {
                "mrum": {
                    "crashReporting": {
                        "enabled": false
                    }
                }
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let config = try XCTUnwrap(CrashReportsRemoteConfiguration(from: data))

        XCTAssertFalse(config.enabled)
    }

    // MARK: - Invalid JSON

    func testEmptyDataReturnsNil() {
        let config = CrashReportsRemoteConfiguration(from: Data())

        XCTAssertNil(config)
    }

    func testMalformedJSONReturnsNil() throws {
        let data = try XCTUnwrap("not valid json".data(using: .utf8))

        let config = CrashReportsRemoteConfiguration(from: data)

        XCTAssertNil(config)
    }

    func testMissingConfigurationKeyReturnsNil() throws {
        let json = """
        {
            "other": {
                "mrum": {
                    "crashReporting": {
                        "enabled": true
                    }
                }
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let config = CrashReportsRemoteConfiguration(from: data)

        XCTAssertNil(config)
    }

    func testMissingMrumKeyReturnsNil() throws {
        let json = """
        {
            "configuration": {
                "other": {}
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let config = CrashReportsRemoteConfiguration(from: data)

        XCTAssertNil(config)
    }

    func testMissingCrashReportingKeyReturnsNil() throws {
        let json = """
        {
            "configuration": {
                "mrum": {
                    "other": {}
                }
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let config = CrashReportsRemoteConfiguration(from: data)

        XCTAssertNil(config)
    }

    func testMissingEnabledFieldReturnsNil() throws {
        let json = """
        {
            "configuration": {
                "mrum": {
                    "crashReporting": {}
                }
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let config = CrashReportsRemoteConfiguration(from: data)

        XCTAssertNil(config)
    }

    func testWrongEnabledTypeReturnsNil() throws {
        let json = """
        {
            "configuration": {
                "mrum": {
                    "crashReporting": {
                        "enabled": "yes"
                    }
                }
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let config = CrashReportsRemoteConfiguration(from: data)

        XCTAssertNil(config)
    }

    func testExtraFieldsDoNotPreventParsing() throws {
        let json = """
        {
            "configuration": {
                "mrum": {
                    "crashReporting": {
                        "enabled": true,
                        "extraField": "ignored"
                    },
                    "otherModule": {}
                },
                "extraConfig": true
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let config = try XCTUnwrap(CrashReportsRemoteConfiguration(from: data))

        XCTAssertTrue(config.enabled)
    }
}
