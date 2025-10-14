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
            URLProtocolMock.setData(response, forPath: path)
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

final class URLProtocolMock: URLProtocol {
    static let mainUrl = URL(string: "https://www.SplunkAgent.test")

    static let testErrorCode = 404

    static let testErrorPath = "error"
    static let testServerErrorPath = "testServerError"

    private static var store: [String: Data] = [:]
    private static let lock = NSLock()

    static func setData(_ data: Data, forPath path: String) {
        lock.lock()
        store[path] = data
        lock.unlock()
    }

    static func data(forPath path: String) -> Data? {
        lock.lock()
        let data = store[path]
        lock.unlock()
        return data
    }

    static func reset() {
        lock.lock()
        store.removeAll()
        lock.unlock()
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let path = url.lastPathComponent

        if path == Self.testErrorPath {
            sendTestError(for: url)
        }
        else if path == Self.testServerErrorPath {
            sendTestErrorPath(for: url)
        }
        else if let data = Self.data(forPath: path) {
            sendData(for: url, data: data)
        }
    }

    override func stopLoading() {}


    // MARK: - Internal client handle response

    func sendTestError(for url: URL) {
        guard
            let response = HTTPURLResponse(
                url: url,
                statusCode: Self.testErrorCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        else {

            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    func sendTestErrorPath(for url: URL) {
        guard
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        else {

            return
        }

        if let body = try? RawMockDataBuilder.build(mockFile: .remoteError) {
            client?.urlProtocol(self, didLoad: body)
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    func sendData(for url: URL, data: Data) {
        guard
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        else {

            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
