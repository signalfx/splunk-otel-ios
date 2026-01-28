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

import Foundation
import XCTest
@testable import SplunkNetwork

final class TaskSupportTests: XCTestCase {

    func testIsSupportedTask_DataTask() throws {
        let session = URLSession.shared
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let task = session.dataTask(with: url)

        XCTAssertTrue(isSupportedTask(task: task))

        task.cancel()
    }

    func testIsSupportedTask_DownloadTask() throws {
        let session = URLSession.shared
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let task = session.downloadTask(with: url)

        XCTAssertTrue(isSupportedTask(task: task))

        task.cancel()
    }

    func testIsSupportedTask_UploadTask() throws {
        let session = URLSession.shared
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let data = Data()
        let task = session.uploadTask(with: URLRequest(url: url), from: data)

        XCTAssertTrue(isSupportedTask(task: task))

        task.cancel()
    }

    func testIsSupportedTask_StreamTask() {
        let session = URLSession.shared
        let task = session.streamTask(withHostName: "example.com", port: 443)

        // Stream tasks are not supported
        XCTAssertFalse(isSupportedTask(task: task))

        task.cancel()
    }
}
