/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

fileprivate let defaultServiceName = "unknown_service:" + ProcessInfo.processInfo.processName

struct ZipkinSpan: Encodable {
    var traceId: String
    var parentId: String?
    var id: String
    var kind: String?
    var name: String
    var timestamp: UInt64
    var duration: UInt64?
    var remoteEndpoint: ZipkinEndpoint?
    var annotations: [ZipkinAnnotation]
    var tags: [String: String]

    init(traceId: String, parentId: String?, id: String, kind: String?, name: String, timestamp: UInt64, duration: UInt64?, remoteEndpoint: ZipkinEndpoint?, annotations: [ZipkinAnnotation], tags: [String: String]) {

        self.traceId = traceId
        self.parentId = parentId
        self.id = id
        self.kind = kind
        self.name = name
        self.timestamp = timestamp
        self.duration = duration
        self.remoteEndpoint = remoteEndpoint
        self.annotations = annotations
        self.tags = tags
    }

    public func write() -> [String: Any] {
        var output = [String: Any]()

        output["traceId"] = traceId
        output["name"] = name
        output["parentId"] = parentId
        output["id"] = id
        output["kind"] = kind
        output["timestamp"] = timestamp
        output["duration"] = duration
        output["localEndpoint"] = ["serviceName": defaultServiceName]

        if remoteEndpoint != nil {
            output["remoteEndpoint"] = remoteEndpoint!.write()
        }

        if annotations.count > 0 {
            let annotationsArray: [Any] = annotations.map {
                var object = [String: Any]()
                object["timestamp"] = $0.timestamp
                object["value"] = $0.value
                return object
            }

            output["annotations"] = annotationsArray
        }

        if tags.count > 0 {
            output["tags"] = tags
        }

        return output
    }
}
