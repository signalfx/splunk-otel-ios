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
import Foundation

final class APIClientTestBuilder {
    public static func buildError() -> APIClient {
        build(with: URLProtocolMock.testErrorPath)
    }

    public static func buildServerError() -> APIClient {
        let errorData = try? RawMockDataBuilder.build(mockFile: .remoteError)
        return build(with: URLProtocolMock.testServerErrorPath, response: errorData)
    }

    public static func build(with path: String, response: Data? = nil) -> APIClient {
        if let response {
            URLProtocolMock.testURLs = [
                path: response
            ]
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self]

        let session = URLSession(configuration: config)

        let url = URL(string: path, relativeTo: URLProtocolMock.mainUrl)

        return APIClient(baseUrl: url!, session: session)
    }
}

struct MockEndpoint: Endpoint {

    typealias RequestHeaders = MockHeaders

    struct MockHeaders: APIClientHeaders {
        var headers = [String: String]()
    }

    static var service = Service(path: "", httpMethod: .get)

    var requestHeaders: MockHeaders?
}

class URLProtocolMock: URLProtocol {
    static var testURLs = [String: Data]()

    static let mainUrl = URL(string: "https://www.SplunkAgent.test")!
    static let testErrorPath = "error"
    static let testServerErrorPath = "testServerError"

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let path = request.url?.lastPathComponent else {
            return
        }

        if path == Self.testErrorPath {
            let response = HTTPURLResponse(url: request.url!, statusCode: Self.testErrorCode, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        } else {
            if
                let errorData = try? RawMockDataBuilder.build(mockFile: .remoteError),
                path == Self.testServerErrorPath {
                client?.urlProtocol(self, didLoad: errorData)

            } else if let data = URLProtocolMock.testURLs[path] {
                client?.urlProtocol(self, didLoad: data)
            }

            client?.urlProtocol(self, didReceive: HTTPURLResponse(), cacheStoragePolicy: .notAllowed)
        }

        client?.urlProtocolDidFinishLoading(self)
    }

    // this method is required but doesn't need to do anything
    override func stopLoading() {}

    static let testErrorCode = 404
}
