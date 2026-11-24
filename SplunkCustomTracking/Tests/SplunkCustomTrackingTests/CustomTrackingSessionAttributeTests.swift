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

@testable import SplunkCommon
@testable import SplunkCustomTracking

/// The agent stamps the session of custom events and errors itself, so the module passes on no app
/// value for `session.id` or `session.previous_id`.
final class CustomTrackingSessionAttributeTests: XCTestCase {
    private static let sessionAttributes: [String: EventAttributeValue] = [
        "session.id": .string("fedcba9876543210fedcba9876543210"),
        "session.previous_id": .string("00112233445566778899aabbccddeeff")
    ]

    func testTrackCustomIgnoresSessionAttributes() throws {
        let attributes = Self.sessionAttributes.merging(["userId": .string("testUser123")]) { $1 }

        let data = try publishedData { module in
            module.track(SplunkTrackableEvent(eventName: "purchase", attributes: attributes))
        }

        XCTAssertEqual(data.attributes, ["userId": .string("testUser123")])
    }

    func testTrackErrorIgnoresSessionAttributes() throws {
        let attributes = Self.sessionAttributes.merging(["resource_url": .string("http://example.com/data.json")]) { $1 }

        let data = try publishedData { module in
            module.track(SplunkIssue(from: "Failed to load resource"), attributes)
        }

        XCTAssertNil(data.attributes["session.id"])
        XCTAssertNil(data.attributes["session.previous_id"])
        XCTAssertEqual(data.attributes["resource_url"], .string("http://example.com/data.json"))
        XCTAssertEqual(data.attributes["error"], .string("true"))
    }

    func testTrackExplicitErrorIgnoresSessionAttributes() throws {
        let issue = SplunkExplicitIssue(typeName: "TypeError", message: "x is undefined", stacktrace: nil)

        let data = try publishedData { module in
            module.trackError(issue, Self.sessionAttributes)
        }

        XCTAssertNil(data.attributes["session.id"])
        XCTAssertNil(data.attributes["session.previous_id"])
        XCTAssertEqual(data.attributes["exception.type"], .string("TypeError"))
    }

    /// An exception always has a stack trace, so it also takes the error diagnostics branch.
    func testTrackExceptionIgnoresSessionAttributes() throws {
        let exception = NSException(name: NSExceptionName("TestException"), reason: "reason", userInfo: nil)

        let data = try publishedData { module in
            module.track(SplunkIssue(from: exception), Self.sessionAttributes)
        }

        XCTAssertNil(data.attributes["session.id"])
        XCTAssertNil(data.attributes["session.previous_id"])
        XCTAssertEqual(data.attributes["exception.type"], .string("TestException"))
    }


    // MARK: - Helpers

    /// The data the module publishes for one tracking call.
    private func publishedData(tracking: (CustomTrackingInternal) -> Void) throws -> CustomTrackingData {
        let module = CustomTrackingInternal()
        var published: CustomTrackingData?
        module.onPublishBlock = { _, data in
            published = data
        }

        tracking(module)

        return try XCTUnwrap(published)
    }
}
