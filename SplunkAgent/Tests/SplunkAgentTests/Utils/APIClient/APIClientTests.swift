//
/*
Copyright 2024 Splunk Inc.

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

@testable import SplunkAgent
import XCTest

class APIClientTests: XCTestCase {

    func testLoadSuccess() async throws {
        let client = APIClientTestBuilder.build(with: Self.testSuccessPath, response: Self.testSuccessResponse)

        let endpoint = MockEndpoint()

        let result = try await client.sendRequest(endpoint: endpoint)

        XCTAssertEqual(result, Self.testSuccessResponse)
    }

    func testLoadErrorCode() async {

        let client = APIClientTestBuilder.buildError()
        let endpoint = MockEndpoint()

        do {
            _ = try await client.sendRequest(endpoint: endpoint)
            XCTFail("Expected to throw an error but did not")
        } catch let error as APIClientError {
            switch error {
            case let .statusCode(code):
                XCTAssertEqual(code, URLProtocolMock.testErrorCode)

            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }


    func testLoadAPIServerError() async {
        let client = APIClientTestBuilder.buildServerError()
        let endpoint = MockEndpoint()

        do {
            _ = try await client.sendRequest(endpoint: endpoint)
            XCTFail("Expected to throw an error but did not")
        } catch let error as APIClientError {
            switch error {
            case let .server(serverDetail):
                XCTAssertEqual(serverDetail.statusCode, 500)

            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    static let testSuccessPath = "success"
    static let testSuccessResponse = Data("Mrum agent test data".utf8)
}
