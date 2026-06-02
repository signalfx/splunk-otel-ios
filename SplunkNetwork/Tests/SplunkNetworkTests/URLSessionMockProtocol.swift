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

final class URLSessionMockProtocol: URLProtocol {

    // MARK: - Constants

    static let host = "mock.splunk.test"


    // MARK: - URLProtocol

    override final static func canInit(with request: URLRequest) -> Bool {
        request.url?.host == host
    }

    override final static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let data = responseData(for: request)
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Content-Length": "\(data.count)"
            ]
        )

        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}


    // MARK: - Utilities

    static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLSessionMockProtocol.self]

        return configuration
    }

    static func url(path: String = "/get") -> URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "https://\(host)\(path)")!
    }


    // MARK: - Private

    private func responseData(for request: URLRequest) -> Data {
        let headers = request.allHTTPHeaderFields ?? [:]
        let object: [String: Any]

        if request.url?.path == "/headers" {
            object = ["headers": headers]
        }
        else {
            object = [
                "headers": headers,
                "ok": true
            ]
        }

        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }
}
