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

@testable import SplunkAgent

enum APIClientTestBuilderError: Error {
    case invalidPath(String)
    case invalidURL(String)
}

final class APIClientTestBuilder {
    static func buildError() throws -> APIClient {
        try build(with: URLProtocolMock.testErrorPath)
    }

    static func buildServerError() throws -> APIClient {
        let errorData = try? RawMockDataBuilder.build(mockFile: .remoteError)
        return try build(with: URLProtocolMock.testServerErrorPath, response: errorData)
    }

    static func build(with path: String, response: Data? = nil) throws -> APIClient {
        if let response {
            URLProtocolMock.testURLs[path] = response
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self]

        let session = URLSession(configuration: config)
        let url = URL(string: path, relativeTo: URLProtocolMock.mainUrl)

        guard let url else {
            throw APIClientTestBuilderError.invalidPath(path)
        }

        return APIClient(baseUrl: url, session: session)
    }
}

struct MockEndpoint: Endpoint {

    typealias RequestHeaders = MockHeaders

    struct MockHeaders: APIClientHeaders {
        var headers: [String: String] = [:]
    }

    static var service = Service(path: "", httpMethod: .get)

    var requestHeaders: MockHeaders?
}

class URLProtocolMock: URLProtocol {
    static var testURLs: [String: Data] = [:]

    static let mainUrl = URL(string: "https://www.SplunkAgent.test")
    static let testErrorPath = "error"
    static let testServerErrorPath = "testServerError"

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let path = request.url?.lastPathComponent else {
            return
        }

        if path == Self.testErrorPath,
            let requestUrl = request.url,
            let response = HTTPURLResponse(url: requestUrl, statusCode: Self.testErrorCode, httpVersion: "HTTP/1.1", headerFields: nil)
        {
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        else {
            if let errorData = try? RawMockDataBuilder.build(mockFile: .remoteError),
                path == Self.testServerErrorPath
            {
                client?.urlProtocol(self, didLoad: errorData)
            }
            else if let data = Self.testURLs[path] {
                client?.urlProtocol(self, didLoad: data)
            }

            client?.urlProtocol(self, didReceive: HTTPURLResponse(), cacheStoragePolicy: .notAllowed)
        }

        client?.urlProtocolDidFinishLoading(self)
    }

    /// Method is required but doesn't need to do anything.
    override func stopLoading() {}

    static let testErrorCode = 404
}
