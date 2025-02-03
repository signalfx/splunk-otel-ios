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

import OpenTelemetryProtocolExporterCommon
import Foundation

/// Defines description of request used to upload exported file
struct RequestDescriptor: Codable {

    // MARK: - Public

    let id: UUID
    let endpoint: URL
    let explicitTimeout: TimeInterval
    var sentCount: Int = 0

    var scheduled: Date {
        Calendar.current.date(byAdding: nextRequestDelay, to: Date()) ?? Date()
    }

    var shouldSend: Bool {
        return sentCount <= 5
    }

    // MARK: - Request creation methods

    func createRequest() -> URLRequest {
        var request = URLRequest(url: endpoint)

        request.httpMethod = "POST"
        request.setValue(Headers.getUserAgentHeader(), forHTTPHeaderField: Constants.HTTP.userAgent)
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = explicitTimeout

        return request
    }

    var json: String? {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return json
    }
}

private extension RequestDescriptor {

    var nextRequestDelay: DateComponents {
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
