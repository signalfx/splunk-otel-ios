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

    func testCrashReportKeysPreviousAppState() {
        XCTAssertEqual(CrashReportKeys.previousAppState.rawValue, "ios.app.state")
    }

    func testCrashReportKeysCrashTimestamp() {
        XCTAssertEqual(CrashReportKeys.crashTimestamp.rawValue, "crash.timestamp")
    }

    func testCrashReportKeysCurrentTimestamp() {
        XCTAssertEqual(CrashReportKeys.currentTimestamp.rawValue, "crash.observedTimestamp")
    }

    // MARK: - Device Information Keys

    func testCrashReportKeysFreeDiskSpace() {
        XCTAssertEqual(CrashReportKeys.freeDiskSpace.rawValue, "crash.freeDiskSpace")
    }

    func testCrashReportKeysBatteryLevel() {
        XCTAssertEqual(CrashReportKeys.batteryLevel.rawValue, "crash.batteryLevel")
    }

    func testCrashReportKeysFreeMemory() {
        XCTAssertEqual(CrashReportKeys.freeMemory.rawValue, "crash.freeMemory")
    }

    func testCrashReportKeysScreenName() {
        XCTAssertEqual(CrashReportKeys.screenName.rawValue, "screen.name")
    }

    func testCrashReportKeysBuildId() {
        XCTAssertEqual(CrashReportKeys.buildId.rawValue, "crash.app.build_id")
    }

    // MARK: - Process Keys

    func testCrashReportKeysProcessPath() {
        XCTAssertEqual(CrashReportKeys.processPath.rawValue, "crash.processPath")
    }

    func testCrashReportKeysIsNative() {
        XCTAssertEqual(CrashReportKeys.isNative.rawValue, "crash.isNative")
    }

    // MARK: - Signal and Fault Keys

    func testCrashReportKeysSignalName() {
        XCTAssertEqual(CrashReportKeys.signalName.rawValue, "signalName")
    }

    func testCrashReportKeysFaultAddress() {
        XCTAssertEqual(CrashReportKeys.faultAddress.rawValue, "crash.address")
    }

    // MARK: - Exception Keys

    func testCrashReportKeysExceptionName() {
        XCTAssertEqual(CrashReportKeys.exceptionName.rawValue, "exception.type")
    }

    func testCrashReportKeysExceptionReason() {
        XCTAssertEqual(CrashReportKeys.exceptionReason.rawValue, "exception.message")
    }

    // MARK: - Thread and Image Keys

    func testCrashReportKeysThreads() {
        XCTAssertEqual(CrashReportKeys.threads.rawValue, "exception.threads")
    }

    func testCrashReportKeysImages() {
        XCTAssertEqual(CrashReportKeys.images.rawValue, "exception.images")
    }

    func testCrashReportKeysDetails() {
        XCTAssertEqual(CrashReportKeys.details.rawValue, "details")
    }

    func testCrashReportKeysComponent() {
        XCTAssertEqual(CrashReportKeys.component.rawValue, "component")
    }

    func testCrashReportKeysError() {
        XCTAssertEqual(CrashReportKeys.error.rawValue, "error")
    }

    // MARK: - Stack Frame Keys

    func testCrashReportKeysInstructionPointer() {
        XCTAssertEqual(CrashReportKeys.instructionPointer.rawValue, "instructionPointer")
    }

    func testCrashReportKeysImageName() {
        XCTAssertEqual(CrashReportKeys.imageName.rawValue, "imageName")
    }

    func testCrashReportKeysSymbolName() {
        XCTAssertEqual(CrashReportKeys.symbolName.rawValue, "symbolName")
    }

    // MARK: - Thread Keys

    func testCrashReportKeysThreadNumber() {
        XCTAssertEqual(CrashReportKeys.threadNumber.rawValue, "threadNumber")
    }

    func testCrashReportKeysStackFrames() {
        XCTAssertEqual(CrashReportKeys.stackFrames.rawValue, "stackFrames")
    }

    func testCrashReportKeysIsCrashedThread() {
        XCTAssertEqual(CrashReportKeys.isCrashedThread.rawValue, "crashed")
    }

    // MARK: - Binary Image Keys

    func testCrashReportKeysBaseAddress() {
        XCTAssertEqual(CrashReportKeys.baseAddress.rawValue, "baseAddress")
    }

    func testCrashReportKeysOffset() {
        XCTAssertEqual(CrashReportKeys.offset.rawValue, "offset")
    }

    func testCrashReportKeysImageSize() {
        XCTAssertEqual(CrashReportKeys.imageSize.rawValue, "imageSize")
    }

    func testCrashReportKeysImagePath() {
        XCTAssertEqual(CrashReportKeys.imagePath.rawValue, "imagePath")
    }

    func testCrashReportKeysImageUUID() {
        XCTAssertEqual(CrashReportKeys.imageUUID.rawValue, "imageUUID")
    }

    // MARK: - Session Key

    func testCrashReportKeysSessionId() {
        XCTAssertEqual(CrashReportKeys.sessionId.rawValue, "session.id")
    }
}
