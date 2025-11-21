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

@testable import SplunkCrashReports

final class CrashReportKeysTests: XCTestCase {

    // MARK: - State and Timestamp Keys

    func testCrashReportKeys_PreviousAppState() {
        XCTAssertEqual(CrashReportKeys.previousAppState.rawValue, "ios.state")
    }

    func testCrashReportKeys_CrashTimestamp() {
        XCTAssertEqual(CrashReportKeys.crashTimestamp.rawValue, "crash.timestamp")
    }

    func testCrashReportKeys_CurrentTimestamp() {
        XCTAssertEqual(CrashReportKeys.currentTimestamp.rawValue, "crash.observedTimestamp")
    }

    // MARK: - Device Information Keys

    func testCrashReportKeys_FreeDiskSpace() {
        XCTAssertEqual(CrashReportKeys.freeDiskSpace.rawValue, "crash.freeDiskSpace")
    }

    func testCrashReportKeys_BatteryLevel() {
        XCTAssertEqual(CrashReportKeys.batteryLevel.rawValue, "crash.batteryLevel")
    }

    func testCrashReportKeys_FreeMemory() {
        XCTAssertEqual(CrashReportKeys.freeMemory.rawValue, "crash.freeMemory")
    }

    func testCrashReportKeys_ScreenName() {
        XCTAssertEqual(CrashReportKeys.screenName.rawValue, "screen.name")
    }

    func testCrashReportKeys_BuildId() {
        XCTAssertEqual(CrashReportKeys.buildId.rawValue, "crash.app.build_id")
    }

    // MARK: - Process Keys

    func testCrashReportKeys_ProcessPath() {
        XCTAssertEqual(CrashReportKeys.processPath.rawValue, "crash.processPath")
    }

    func testCrashReportKeys_IsNative() {
        XCTAssertEqual(CrashReportKeys.isNative.rawValue, "crash.isNative")
    }

    // MARK: - Signal and Fault Keys

    func testCrashReportKeys_SignalName() {
        XCTAssertEqual(CrashReportKeys.signalName.rawValue, "signalName")
    }

    func testCrashReportKeys_FaultAddress() {
        XCTAssertEqual(CrashReportKeys.faultAddress.rawValue, "crash.address")
    }

    // MARK: - Exception Keys

    func testCrashReportKeys_ExceptionName() {
        XCTAssertEqual(CrashReportKeys.exceptionName.rawValue, "exception.type")
    }

    func testCrashReportKeys_ExceptionReason() {
        XCTAssertEqual(CrashReportKeys.exceptionReason.rawValue, "exception.message")
    }

    // MARK: - Thread and Image Keys

    func testCrashReportKeys_Threads() {
        XCTAssertEqual(CrashReportKeys.threads.rawValue, "exception.threads")
    }

    func testCrashReportKeys_Images() {
        XCTAssertEqual(CrashReportKeys.images.rawValue, "exception.images")
    }

    func testCrashReportKeys_Details() {
        XCTAssertEqual(CrashReportKeys.details.rawValue, "details")
    }

    func testCrashReportKeys_Component() {
        XCTAssertEqual(CrashReportKeys.component.rawValue, "component")
    }

    func testCrashReportKeys_Error() {
        XCTAssertEqual(CrashReportKeys.error.rawValue, "error")
    }

    // MARK: - Stack Frame Keys

    func testCrashReportKeys_InstructionPointer() {
        XCTAssertEqual(CrashReportKeys.instructionPointer.rawValue, "instructionPointer")
    }

    func testCrashReportKeys_ImageName() {
        XCTAssertEqual(CrashReportKeys.imageName.rawValue, "imageName")
    }

    func testCrashReportKeys_SymbolName() {
        XCTAssertEqual(CrashReportKeys.symbolName.rawValue, "symbolName")
    }

    // MARK: - Thread Keys

    func testCrashReportKeys_ThreadNumber() {
        XCTAssertEqual(CrashReportKeys.threadNumber.rawValue, "threadNumber")
    }

    func testCrashReportKeys_StackFrames() {
        XCTAssertEqual(CrashReportKeys.stackFrames.rawValue, "stackFrames")
    }

    func testCrashReportKeys_IsCrashedThread() {
        XCTAssertEqual(CrashReportKeys.isCrashedThread.rawValue, "crashed")
    }

    // MARK: - Binary Image Keys

    func testCrashReportKeys_BaseAddress() {
        XCTAssertEqual(CrashReportKeys.baseAddress.rawValue, "baseAddress")
    }

    func testCrashReportKeys_Offset() {
        XCTAssertEqual(CrashReportKeys.offset.rawValue, "offset")
    }

    func testCrashReportKeys_ImageSize() {
        XCTAssertEqual(CrashReportKeys.imageSize.rawValue, "imageSize")
    }

    func testCrashReportKeys_ImagePath() {
        XCTAssertEqual(CrashReportKeys.imagePath.rawValue, "imagePath")
    }

    func testCrashReportKeys_ImageUUID() {
        XCTAssertEqual(CrashReportKeys.imageUUID.rawValue, "imageUUID")
    }

    // MARK: - Session Key

    func testCrashReportKeys_SessionId() {
        XCTAssertEqual(CrashReportKeys.sessionId.rawValue, "session.id")
    }
}
