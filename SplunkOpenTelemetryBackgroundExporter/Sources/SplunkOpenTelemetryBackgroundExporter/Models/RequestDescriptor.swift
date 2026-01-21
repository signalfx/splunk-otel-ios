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
import OpenTelemetryProtocolExporterCommon

protocol RequestDescriptorProtocol: Codable {
    var id: UUID { get }
    var endpoint: URL { get }
    var explicitTimeout: TimeInterval { get }
    var sentCount: Int { get set }
    var fileKeyType: String { get }
    var scheduled: Date { get }
    var shouldSend: Bool { get }
    var headers: [String: String] { get }

    func createRequest() -> URLRequest
}

extension RequestDescriptorProtocol {
    var json: String? {
        guard let data = try? JSONEncoder().encode(self),
            let json = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return json
    }
}

/// Defines description of request used to upload exported file.
struct RequestDescriptor: RequestDescriptorProtocol {

    // MARK: - Public

    let id: UUID
    let endpoint: URL
    let explicitTimeout: TimeInterval
    var sentCount: Int = 0
    var fileKeyType: String
    var headers: [String: String] = [:]

    var scheduled: Date {
        Calendar.current.date(byAdding: nextRequestDelay, to: Date()) ?? Date()
    }

    var shouldSend: Bool {
        sentCount <= 5
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case endpoint
        case explicitTimeout
        case sentCount
        case fileKeyType
        case headers
    }

    init(
        id: UUID,
        endpoint: URL,
        explicitTimeout: TimeInterval,
        sentCount: Int = 0,
        fileKeyType: String,
        headers: [String: String] = [:]
    ) {
        self.id = id
        self.endpoint = endpoint
        self.explicitTimeout = explicitTimeout
        self.sentCount = sentCount
        self.fileKeyType = fileKeyType
        self.headers = headers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        endpoint = try container.decode(URL.self, forKey: .endpoint)
        explicitTimeout = try container.decode(TimeInterval.self, forKey: .explicitTimeout)
        sentCount = try container.decode(Int.self, forKey: .sentCount)
        fileKeyType = try container.decode(String.self, forKey: .fileKeyType)
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(endpoint, forKey: .endpoint)
        try container.encode(explicitTimeout, forKey: .explicitTimeout)
        try container.encode(sentCount, forKey: .sentCount)
        try container.encode(fileKeyType, forKey: .fileKeyType)
        try container.encode(headers, forKey: .headers)
    }

    // MARK: - Request creation methods

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

extension RequestDescriptor {

    private var nextRequestDelay: DateComponents {
        var delay = DateComponents()

        switch sentCount {
        case 0:
            delay.second = 0

        case 1:
            delay.minute = 1

        case 2:
            delay.minute = 10

        case 3:
            delay.minute = 30

        case 4:
            delay.hour = 1

        default:
            delay.day = 1
        }

        return delay
    }
}
