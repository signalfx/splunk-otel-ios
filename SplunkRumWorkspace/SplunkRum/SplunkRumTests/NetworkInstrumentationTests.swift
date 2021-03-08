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

// Fake span structure for JSONDecoder, only care about tags at the moment
struct TestZipkinSpan: Decodable {
    var name: String
    var tags: [String: String]
}

class NetworkInstrumentationTests: XCTestCase {
    func testBasics() throws {
        try initializeTestEnvironment()

        // Not going to exhaustively test all the api variations, particularly since
        // they all flow through the same bit of code
        URLSession.shared.dataTask(with: URL(string: "http://127.0.0.1:8989/data")!) { (_, _: URLResponse?, _) in
            print("got /data")
        }.resume()
        var req = URLRequest(url: URL(string: "http://127.0.0.1:8989/error")!)
        req.httpMethod = "POST"
        URLSession.shared.uploadTask(with: req, from: "sample data".data(using: .utf8)!).resume()

        // FIXME config option to dial back the batch period
        print("sleeping to wait for span batch, don't worry about the pause...")
        sleep(8)
        print(receivedSpans as Any)
        let httpGet = receivedSpans.first(where: { (span) -> Bool in
            return span.name == "HTTP GET"
        })
        let httpPost = receivedSpans.first(where: { (span) -> Bool in
            return span.name == "HTTP POST"
        })
        let beacon = receivedSpans.first(where: { (span) -> Bool in
            return span.tags["http.url"]?.contains("/v1/traces") ?? false
        })

        XCTAssertNotNil(httpGet)
        XCTAssertEqual(httpGet?.tags["http.url"], "http://127.0.0.1:8989/data")
        XCTAssertEqual(httpGet?.tags["http.method"], "GET")
        XCTAssertEqual(httpGet?.tags["http.status_code"], "200")
        XCTAssertEqual(httpGet?.tags["http.response_content_length_uncompressed"], "17")

        XCTAssertNotNil(httpPost)
        XCTAssertEqual(httpPost?.tags["http.url"], "http://127.0.0.1:8989/error")
        XCTAssertEqual(httpPost?.tags["http.method"], "POST")
        XCTAssertEqual(httpPost?.tags["http.status_code"], "500")
        XCTAssertEqual(httpPost?.tags["http.request_content_length"], "11")

        XCTAssertNil(beacon)

        // FIXME not a great place to shoehorn it currently, but checking the globalAttributes logic here
        XCTAssertEqual("7", httpPost?.tags["intKey"])
        XCTAssertEqual("1.5", httpPost?.tags["doubleKey"])
        XCTAssertEqual("true", httpPost?.tags["boolKey"])
        XCTAssertEqual("strVal", httpPost?.tags["strKey"])

    }
}
