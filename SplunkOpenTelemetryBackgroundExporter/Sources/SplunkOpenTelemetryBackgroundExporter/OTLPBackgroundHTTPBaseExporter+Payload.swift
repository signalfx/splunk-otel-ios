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

import CiscoDiskStorage
import Foundation

extension OTLPBackgroundHTTPBaseExporter {
    /// Persists a payload while no endpoint is configured and activates it if an endpoint appeared during the write.
    func storePendingData(_ data: Data, requestId: UUID) throws {
        try diskStorage.insert(
            data,
            forKey: KeyBuilder(
                requestId.uuidString,
                parrentKeyBuilder: getPendingStorageKey()
            )
        )
        activatePendingDataIfEndpointAvailable()
    }

    func buildHeaders(from additionalHeaders: [String: String]) -> [String: String] {
        var combinedHeaders = [
            OTLPHTTPHeaders.userAgentKey: OTLPHTTPHeaders.userAgent(agentVersion: config.agentVersion)
        ]

        for (key, value) in additionalHeaders {
            combinedHeaders[normalizedHeaderKey(key)] = value
        }

        if let envVarHeaders {
            for (key, value) in envVarHeaders {
                combinedHeaders[normalizedHeaderKey(key)] = value
            }
        }
        return combinedHeaders
    }

    func normalizedHeaderKey(_ key: String) -> String {
        if key.caseInsensitiveCompare(OTLPHTTPHeaders.userAgentKey) == .orderedSame {
            return OTLPHTTPHeaders.userAgentKey
        }

        return key
    }

    func inferPayloadFormat(forFileKey fileKey: String) -> RequestPayloadFormat {
        guard
            let fileURL = try? diskStorage.finalDestination(forKey: getStorageKey().append(fileKey)),
            let payloadData = try? Data(contentsOf: fileURL)
        else {
            return .json
        }

        if (try? JSONSerialization.jsonObject(with: payloadData)) != nil {
            return .json
        }

        return .protobuf
    }
}
