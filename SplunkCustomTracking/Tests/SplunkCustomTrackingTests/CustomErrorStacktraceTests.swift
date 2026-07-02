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

@testable import SplunkCustomTracking

final class CustomErrorStacktraceTests: XCTestCase {

    func testThreadListOmitsUnavailableThreadMetadata() throws {
        let stacktrace = Stacktrace(frames: [
            "0   AgentTestApp                        0x0000000100e84234 specialized Foo.bar() + 24",
            "1   UIKitCore                           0x00000001852f3710 -[UIApplication sendAction:to:from:forEvent:] + 96"
        ])

        let threadsJSON = try XCTUnwrap(stacktrace.threadList)
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(threadsJSON.utf8)) as? [[String: Any]])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertNil(parsed[0]["threadNumber"])
        XCTAssertNil(parsed[0]["crashed"])

        let stackFrames = try XCTUnwrap(parsed[0]["stackFrames"] as? [[String: Any]])
        XCTAssertEqual(stackFrames.count, 2)
        XCTAssertEqual(stackFrames[0]["imageName"] as? String, "AgentTestApp")
        XCTAssertEqual(stackFrames[0]["instructionPointer"] as? UInt64, 4_310_188_596)
        XCTAssertEqual(stackFrames[0]["symbolName"] as? String, "specialized Foo.bar()")
        XCTAssertEqual(stackFrames[0]["offset"] as? UInt64, 24)
        XCTAssertEqual(stackFrames[1]["imageName"] as? String, "UIKitCore")
        XCTAssertEqual(stackFrames[1]["instructionPointer"] as? UInt64, 6_529_431_308)
        XCTAssertEqual(stackFrames[1]["offset"] as? UInt64, 92)
        XCTAssertEqual(stacktrace.referencedImageNames, Set(["AgentTestApp", "UIKitCore"]))
    }

    func testThreadListResolvesImageNameFromInstructionPointer() throws {
        let stacktrace = Stacktrace(frames: [
            "0   AgentTestApp                        0x0000000100e84234 specialized Foo.bar() + 24",
            "1   UIKitCore                           0x00000001852f3710 -[UIApplication sendAction:to:from:forEvent:] + 96"
        ])

        let threadsJSON = try XCTUnwrap(
            stacktrace.threadList { instructionPointer, parsedImageName in
                switch instructionPointer {
                case 4_310_188_596:
                    "/private/var/containers/Bundle/Application/Test/AgentTestApp.app/AgentTestApp"

                default:
                    parsedImageName
                }
            }
        )
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(threadsJSON.utf8)) as? [[String: Any]])
        let stackFrames = try XCTUnwrap(parsed[0]["stackFrames"] as? [[String: Any]])

        XCTAssertEqual(
            stackFrames[0]["imageName"] as? String,
            "/private/var/containers/Bundle/Application/Test/AgentTestApp.app/AgentTestApp"
        )
        XCTAssertEqual(stackFrames[1]["imageName"] as? String, "UIKitCore")
    }

    func testThreadListDropsParsedSymbolInfoWhenAdjustedAddressPrecedesSymbol() throws {
        let stacktrace = Stacktrace(frames: [
            "0   AgentTestApp                        0x0000000100e84234 specialized Foo.bar() + 24",
            "1   AgentTestApp                        0x0000000100e84234 symbolNearReturnAddress() + 2"
        ])

        let threadsJSON = try XCTUnwrap(stacktrace.threadList)
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(threadsJSON.utf8)) as? [[String: Any]])
        let stackFrames = try XCTUnwrap(parsed[0]["stackFrames"] as? [[String: Any]])

        XCTAssertEqual(stackFrames[1]["imageName"] as? String, "AgentTestApp")
        XCTAssertEqual(stackFrames[1]["instructionPointer"] as? UInt64, 4_310_188_592)
        XCTAssertNil(stackFrames[1]["symbolName"])
        XCTAssertNil(stackFrames[1]["offset"])
    }
}
