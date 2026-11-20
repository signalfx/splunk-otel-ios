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

@testable import SplunkAgent

/// An API client that never starts a request.
///
/// Each request fails at once with the same error that the `URLProtocolMock` error path returns, so
/// the configuration handler of a test agent behaves as before but sends no request. Without a
/// request, the network instrumentation of agents installed by other tests records no `HTTP GET`
/// span for it.
final class NoRequestAPIClient: AgentAPIClient {

    // MARK: - AgentAPIClient

    // `AgentAPIClient` requires `async`, but this client has nothing to wait for
    // swiftlint:disable:next async_without_await
    func sendRequest(endpoint _: some Endpoint) async throws -> Data {
        throw APIClientError.statusCode(URLProtocolMock.testErrorCode)
    }
}
