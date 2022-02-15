//
/*
Copyright 2021 Splunk Inc.

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
import Atomics
class ConnectionInstrumentationTests: XCTestCase {
    func testConnection() throws {
        try initializeTestEnvironment()
        var req = URLRequest(url: URL(string: "http://127.0.0.1:8989/data")!)
        req.httpMethod = "GET"
        var response: URLResponse? = URLResponse()
        _ = try? NSURLConnection.sendSynchronousRequest(req, returning: &response)
        var reqerror = URLRequest(url: URL(string: "http://127.0.0.1:8989/error")!)
        reqerror.httpMethod = "POST"
        _ = try? NSURLConnection.sendSynchronousRequest(reqerror, returning: &response)
        var ephemReq = URLRequest(url: URL(string: "http://this.domain.willnotroute/")!)
        ephemReq.httpMethod = "HEAD"
        _ = try? NSURLConnection.sendSynchronousRequest(ephemReq, returning: &response)
       testHttpData()
    }
    func testHttpData() {
        var attempts = 0
        while localSpans.count < 3 {
            attempts += 1
            if attempts > 10 {
                XCTFail("never got enough localSpans")
                return
            }
            print("sleep 1")
            sleep(1)
        }
        XCTAssertEqual(localSpans.count, 3)
        let httpGet = localSpans.first(where: { (span) -> Bool in
            return span.name == "HTTP GET"
        })
        let httpPost = localSpans.first(where: { (span) -> Bool in
            return span.name == "HTTP POST"
        })
        let httpHead = localSpans.first(where: { (span) -> Bool in
            return span.name == "HTTP HEAD"
        })
        XCTAssertNotNil(httpGet)
        XCTAssertEqual(httpGet?.attributes["http.url"]?.description, "http://127.0.0.1:8989/data")
        XCTAssertEqual(httpGet?.attributes["http.method"]?.description, "GET")
        XCTAssertEqual(httpGet?.attributes["http.status_code"]?.description, "200")
        XCTAssertEqual(httpGet?.attributes["http.response_content_length_uncompressed"]?.description, "17")
        XCTAssertEqual(httpGet?.attributes["link.traceId"]?.description, "0af7651916cd43dd8448eb211c80319c")
        XCTAssertEqual(httpGet?.attributes["link.spanId"]?.description, "b7ad6b7169203331")
        XCTAssertEqual(httpGet?.attributes["component"]?.description, "http")
        XCTAssertNotNil(httpPost)
        XCTAssertEqual(httpPost?.attributes["http.url"]?.description, "http://127.0.0.1:8989/error")
        XCTAssertEqual(httpPost?.attributes["http.method"]?.description, "POST")
        XCTAssertEqual(httpPost?.attributes["http.status_code"]?.description, "500")
        XCTAssertEqual(httpPost?.attributes["http.request_content_length"]?.description, "0")
        XCTAssertEqual(httpPost?.attributes["component"]?.description, "http")
        XCTAssertNotNil(httpHead)
        XCTAssertEqual(httpHead?.attributes["http.url"]?.description, "http://this.domain.willnotroute/")
        XCTAssertEqual(httpHead?.attributes["error"]?.description, "true")
        XCTAssertEqual(httpHead?.attributes["exception.type"]?.description, "NSURLError")
        XCTAssertEqual(httpHead?.attributes["component"]?.description, "http")
        XCTAssert((httpHead?.attributes["exception.message"]?.description.count ?? 0) > 10)
    }
}
