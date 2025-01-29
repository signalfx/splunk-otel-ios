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

import Foundation

/// Defines the basic client for API communication
class APIClient: AgentAPIClient {

    // MARK: - Variables

    var baseUrl: URL
    var session: URLSession


    // MARK: - Inicialization

    init(baseUrl: URL, session: URLSession = URLSession.shared) {
        self.baseUrl = baseUrl
        self.session = session
    }


    // MARK: - Loading function

    func sendRequest<T: Endpoint>(endpoint: T) async throws -> Data {

        // Construct final url
        let url = endpoint.url(with: baseUrl)

        // Create request with method
        var request = URLRequest(url: url)
        request.httpMethod = T.service.httpMethod.rawValue

        // Append request headers
        request.allHTTPHeaderFields = endpoint.requestHeaders?.headers

        // Make api call
        let data: Data
        let response: URLResponse

        do {
            let result = try await session.data(for: request)
            data = result.0
            response = result.1
        } catch {
            throw APIClientError.sessionDataFailed
        }

        // Check for http error response
        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode

            guard statusCode >= 200 && statusCode <= 299 else {
                throw APIClientError.statusCode(statusCode)
            }
        }

        guard !data.isEmpty else {
            throw APIClientError.noData
        }

        // Check for server error response or return loaded data
        if let errorModel = try? JSONDecoder().decode(APIClientError.ServerDetail.self, from: data) {
            throw APIClientError.server(errorModel)
        } else {
            return data
        }
    }
}
