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

import CiscoEncryption
import Foundation
import OpenTelemetryProtocolExporterCommon
import SplunkCommon
import Testing
@testable import SplunkOpenTelemetryBackgroundExporter

struct MockRequestDescriptor: RequestDescriptorProtocol {

    var id: UUID
    var endpoint: URL
    var explicitTimeout: TimeInterval
    var sentCount: Int
    var fileKeyType: String
    var scheduled: Date
    var shouldSend: Bool
    var headers: [String: String]

    init(
        endpointString: String = "https://example.com",
        id: UUID = .init(),
        explicitTimeout: TimeInterval = 1,
        sentCount: Int = 0,
        fileKeyType: String = "base",
        scheduled: Date = Date(),
        shouldSend: Bool = true,
        headers: [String: String] = [:]
    ) throws {
        guard let url = URL(string: endpointString) else {
            throw URLError(.unknown)
        }

        endpoint = url
        self.id = id
        self.explicitTimeout = explicitTimeout
        self.sentCount = sentCount
        self.fileKeyType = fileKeyType
        self.scheduled = scheduled
        self.shouldSend = shouldSend
        self.headers = headers
    }

    func createRequest() -> URLRequest {
        var request = URLRequest(url: endpoint)

        request.httpMethod = "POST"
        request.setValue(Headers.getUserAgentHeader(), forHTTPHeaderField: Constants.HTTP.userAgent)
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = explicitTimeout

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }
}
