//
/*
Copyright 2021 Splunk Inc.

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
import OpenTelemetryApi
import OpenTelemetrySdk

class ZipkinEndpoint: Encodable {
    var serviceName: String
    var ipv4: String?
    var ipv6: String?
    var port: Int?

    public init(serviceName: String, ipv4: String? = nil, ipv6: String? = nil, port: Int? = nil) {
        self.serviceName = serviceName
        self.ipv4 = ipv4
        self.ipv6 = ipv6
        self.port = port
    }

    public func clone(serviceName: String) -> ZipkinEndpoint {
        return ZipkinEndpoint(serviceName: serviceName, ipv4: ipv4, ipv6: ipv6, port: port)
    }

    public func write() -> [String: Any] {
        var output = [String: Any]()

        output["serviceName"] = serviceName
        output["ipv4"] = ipv4
        output["ipv6"] = ipv6
        output["port"] = port

        return output
    }
}

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
    var debug: Bool?
    var shared: Bool?

    init(traceId: String, parentId: String?, id: String, kind: String?, name: String, timestamp: UInt64, duration: UInt64?, remoteEndpoint: ZipkinEndpoint?, annotations: [ZipkinAnnotation], tags: [String: String], debug: Bool?, shared: Bool?) {

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
        self.debug = debug
        self.shared = shared
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
        output["debug"] = debug
        output["shared"] = shared
        output["localEndpoint"] = ["serviceName":"app"]

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

struct ZipkinAnnotation: Encodable {
    var timestamp: UInt64
    var value: String
}

struct ZipkinTransform {
    static let statusCode = "otel.status_code"
    static let statusErrorDescription = "error"

    static let remoteEndpointServiceNameKeyResolution = ["peer.service": 0,
                                                         "net.peer.name": 1,
                                                         "peer.hostname": 2,
                                                         "peer.address": 2,
                                                         "http.host": 3,
                                                         "db.instance": 4]

    static var remoteEndpointCache = [String: ZipkinEndpoint]()

    static let defaultServiceName = "unknown_service:" + ProcessInfo.processInfo.processName

    struct AttributeEnumerationState {
        var tags = [String: String]()
        var RemoteEndpointServiceName: String?
        var remoteEndpointServiceNamePriority: Int?
        var serviceName: String?
        var serviceNamespace: String?
    }
    
    static func toZipkinSpans(spans: [SpanData]) -> [ZipkinSpan] {
        return spans.map { ZipkinTransform.toZipkinSpan(otelSpan: $0) }
    }

    static func toZipkinSpan(otelSpan: SpanData, useShortTraceIds: Bool = false) -> ZipkinSpan {
        let parentId = otelSpan.parentSpanId?.hexString ?? SpanId.invalid.hexString

        var attributeEnumerationState = AttributeEnumerationState()

        otelSpan.attributes.forEach {
            processAttributes(state: &attributeEnumerationState, key: $0.key, value: $0.value)
        }

        otelSpan.resource.attributes.forEach {
            processResources(state: &attributeEnumerationState, key: $0.key, value: $0.value)
        }

        if let serviceNamespace = attributeEnumerationState.serviceNamespace, !serviceNamespace.isEmpty {
            attributeEnumerationState.tags["service.namespace"] = serviceNamespace
        }

        var remoteEndpoint: ZipkinEndpoint?
        if otelSpan.kind == .client || otelSpan.kind == .producer, attributeEnumerationState.RemoteEndpointServiceName != nil {
            remoteEndpoint = remoteEndpointCache[attributeEnumerationState.RemoteEndpointServiceName!]
            if remoteEndpoint == nil {
                remoteEndpoint = ZipkinEndpoint(serviceName: attributeEnumerationState.RemoteEndpointServiceName!)
                remoteEndpointCache[attributeEnumerationState.RemoteEndpointServiceName!] = remoteEndpoint!
            }
        }

        let status = otelSpan.status
        if status != .unset {
            attributeEnumerationState.tags[statusCode] = "\(status.name)".uppercased()
        }
        if case let Status.error(description) = status {
            attributeEnumerationState.tags[statusErrorDescription] = description
        }

        let annotations = otelSpan.events.map { processEvents(event: $0) }

        return ZipkinSpan(traceId: ZipkinTransform.EncodeTraceId(traceId: otelSpan.traceId, useShortTraceIds: useShortTraceIds),
                          parentId: parentId,
                          id: ZipkinTransform.EncodeSpanId(spanId: otelSpan.spanId),
                          kind: ZipkinTransform.toSpanKind(otelSpan: otelSpan),
                          name: otelSpan.name,
                          timestamp: otelSpan.startTime.timeIntervalSince1970.toMicroseconds,
                          duration: otelSpan.endTime.timeIntervalSince(otelSpan.startTime).toMicroseconds,
                          remoteEndpoint: remoteEndpoint,
                          annotations: annotations,
                          tags: attributeEnumerationState.tags,
                          debug: nil,
                          shared: nil)
    }

    static func EncodeSpanId(spanId: SpanId) -> String {
        return spanId.hexString
    }

    private static func EncodeTraceId(traceId: TraceId, useShortTraceIds: Bool) -> String {
        if useShortTraceIds {
            return String(format: "%016llx", traceId.rawLowerLong)
        } else {
            return traceId.hexString
        }
    }

    private static func toSpanKind(otelSpan: SpanData) -> String? {
        switch otelSpan.kind {
        case .client:
            return "CLIENT"
        case .server:
            return "SERVER"
        case .producer:
            return "PRODUCER"
        case .consumer:
            return "CONSUMER"
        default:
            return nil
        }
    }

    private static func processEvents(event: SpanData.Event) -> ZipkinAnnotation {
        return ZipkinAnnotation(timestamp: event.timestamp.timeIntervalSince1970.toMicroseconds, value: event.name)
    }

    private static func processAttributes(state: inout AttributeEnumerationState, key: String, value: AttributeValue) {
        if case let .string(val) = value, let priority = remoteEndpointServiceNameKeyResolution[key] {
            if state.RemoteEndpointServiceName == nil || priority < state.remoteEndpointServiceNamePriority ?? 5 {
                state.RemoteEndpointServiceName = val
                state.remoteEndpointServiceNamePriority = priority
            }
            state.tags[key] = val
        } else {
            state.tags[key] = value.description
        }
    }

    private static func processResources(state: inout AttributeEnumerationState, key: String, value: AttributeValue) {
        if case let .string(val) = value {
            if key == ResourceAttributes.serviceName {
                state.serviceName = val
            } else if key == ResourceAttributes.serviceNamespace {
                state.serviceNamespace = val
            } else {
                state.tags[key] = val
            }
        } else {
            state.tags[key] = value.description
        }
    }
}
