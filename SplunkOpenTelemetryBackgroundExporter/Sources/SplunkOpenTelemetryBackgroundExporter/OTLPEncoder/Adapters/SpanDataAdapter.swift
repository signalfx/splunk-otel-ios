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
import OpenTelemetryApi
import OpenTelemetrySdk

// MARK: - SpanDataAdapter

/// Adapter for converting OpenTelemetry SDK SpanData to OTLP JSON models.
///
/// This adapter handles:
/// - Grouping spans by resource and instrumentation scope
/// - Converting SpanData to OTLPSpan with proper encoding (hex IDs, integer enums)
/// - Filtering out empty envelopes per OTLP spec
///
/// Based on OTLP specification v1.9.0.
enum SpanDataAdapter {

    // MARK: - Private Types

    /// Key for grouping spans by scope within a resource.
    ///
    /// Uses scope name and version as the grouping key.
    private struct ScopeKey: Hashable {
        let name: String
        let version: String?

        init(from scope: InstrumentationScopeInfo?) {
            name = scope?.name ?? ""
            version = scope?.version
        }
    }


    // MARK: - Public Methods

    /// Converts a list of SpanData to OTLP ResourceSpans.
    ///
    /// Groups spans by resource and instrumentation scope, then converts them to
    /// OTLP JSON models. Empty envelopes are filtered out.
    ///
    /// - Parameter spans: The list of SpanData to convert.
    /// - Returns: A list of OTLPResourceSpans (non-empty).
    static func toResourceSpans(_ spans: [SpanData]) -> [OTLPResourceSpans] {
        // Group spans by resource first
        let groupedByResource = groupByResource(spans)

        var resourceSpansList: [OTLPResourceSpans] = []

        for (resource, spanDataList) in groupedByResource {
            // Group spans within this resource by scope
            let groupedByScope = groupByScope(spanDataList)

            var scopeSpansList: [OTLPScopeSpans] = []

            for (_, scopedSpans) in groupedByScope {
                // Convert each SpanData to OTLPSpan
                let otlpSpans = scopedSpans.map { convertSpan($0) }

                // Skip empty scope spans (filter empty envelopes per OTLP spec)
                guard !otlpSpans.isEmpty else {
                    continue
                }

                // Get the scope info from the first span in this scope group
                let scope = convertInstrumentationScope(scopedSpans.first?.instrumentationScope)

                let scopeSpans = OTLPScopeSpans(
                    scope: scope,
                    spans: otlpSpans,
                    schemaUrl: nil
                )
                scopeSpansList.append(scopeSpans)
            }

            // Skip empty resource spans (filter empty envelopes per OTLP spec)
            guard !scopeSpansList.isEmpty else {
                continue
            }

            let resourceSpans = OTLPResourceSpans(
                resource: convertResource(resource),
                scopeSpans: scopeSpansList,
                schemaUrl: nil // Resource.schemaUrl not available in current SDK version
            )
            resourceSpansList.append(resourceSpans)
        }

        return resourceSpansList
    }


    // MARK: - Private Grouping Methods

    /// Groups spans by resource.
    private static func groupByResource(_ spans: [SpanData]) -> [Resource: [SpanData]] {
        var result: [Resource: [SpanData]] = [:]

        for span in spans {
            result[span.resource, default: []].append(span)
        }

        return result
    }

    /// Groups spans by instrumentation scope within a resource.
    private static func groupByScope(_ spans: [SpanData]) -> [ScopeKey: [SpanData]] {
        var result: [ScopeKey: [SpanData]] = [:]

        for span in spans {
            let key = ScopeKey(from: span.instrumentationScope)
            result[key, default: []].append(span)
        }

        return result
    }


    // MARK: - Private Conversion Methods

    /// Converts a SpanData to an OTLPSpan.
    private static func convertSpan(_ spanData: SpanData) -> OTLPSpan {
        OTLPSpan(
            traceId: OTLPTraceId(from: spanData.traceId),
            spanId: OTLPSpanId(from: spanData.spanId),
            traceState: spanData.traceState.entries.isEmpty ? nil : traceStateToString(spanData.traceState),
            parentSpanId: spanData.parentSpanId.map { OTLPSpanId(from: $0) },
            name: spanData.name,
            // SpanKind raw value: internal=0, server=1, client=2, producer=3, consumer=4
            // OTLP uses: unspecified=0, internal=1, server=2, client=3, producer=4, consumer=5
            kind: convertSpanKind(spanData.kind),
            startTimeUnixNano: OTLPUInt64(spanData.startTime.timeIntervalSince1970.toNanoseconds),
            endTimeUnixNano: OTLPUInt64(spanData.endTime.timeIntervalSince1970.toNanoseconds),
            attributes: convertAttributes(spanData.attributes),
            droppedAttributesCount: calculateDroppedCount(total: spanData.totalAttributeCount, actual: spanData.attributes.count),
            events: convertEvents(spanData.events),
            droppedEventsCount: calculateDroppedCount(total: spanData.totalRecordedEvents, actual: spanData.events.count),
            links: convertLinks(spanData.links),
            droppedLinksCount: calculateDroppedCount(total: spanData.totalRecordedLinks, actual: spanData.links.count),
            status: convertStatus(spanData.status),
            // W3C trace flags - pass through the byte value
            flags: UInt32(spanData.traceFlags.byte)
        )
    }

    /// Converts TraceState to W3C header format string.
    private static func traceStateToString(_ traceState: TraceState) -> String {
        traceState.entries.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
    }

    /// Converts SpanKind to OTLP integer value.
    ///
    /// OTLP: unspecified=0, internal=1, server=2, client=3, producer=4, consumer=5
    private static func convertSpanKind(_ kind: SpanKind) -> Int {
        switch kind {
        case .internal:
            return 1

        case .server:
            return 2

        case .client:
            return 3

        case .producer:
            return 4

        case .consumer:
            return 5

        @unknown default:
            return 0 // UNSPECIFIED
        }
    }

    /// Converts Resource to OTLPResource.
    private static func convertResource(_ resource: Resource) -> OTLPResource {
        OTLPResource(
            attributes: convertAttributes(resource.attributes) ?? [],
            droppedAttributesCount: nil // SDK doesn't track this
        )
    }

    /// Converts InstrumentationScopeInfo to OTLPInstrumentationScope.
    private static func convertInstrumentationScope(_ scopeInfo: InstrumentationScopeInfo?) -> OTLPInstrumentationScope? {
        guard let scopeInfo else {
            return nil
        }

        let attrs = scopeInfo.attributes ?? [:]
        return OTLPInstrumentationScope(
            name: scopeInfo.name,
            version: scopeInfo.version,
            attributes: attrs.isEmpty ? nil : convertAttributes(attrs),
            droppedAttributesCount: nil
        )
    }

    /// Converts attributes dictionary to array of OTLPKeyValue.
    private static func convertAttributes(_ attributes: [String: AttributeValue]) -> [OTLPKeyValue]? {
        guard !attributes.isEmpty else {
            return nil
        }

        return attributes.map { key, value in
            OTLPKeyValue(key: key, value: convertAttributeValue(value))
        }
    }

    /// Converts an AttributeValue to OTLPAnyValue.
    private static func convertAttributeValue(_ value: AttributeValue) -> OTLPAnyValue {
        switch value {
        case let .string(stringValue):
            return .stringValue(stringValue)

        case let .bool(boolValue):
            return .boolValue(boolValue)

        case let .int(intValue):
            return .intValue(Int64(intValue))

        case let .double(doubleValue):
            return .doubleValue(doubleValue)

        case let .stringArray(arr):
            return .arrayValue(OTLPArrayValue(values: arr.map { .stringValue($0) }))

        case let .boolArray(arr):
            return .arrayValue(OTLPArrayValue(values: arr.map { .boolValue($0) }))

        case let .intArray(arr):
            return .arrayValue(OTLPArrayValue(values: arr.map { .intValue(Int64($0)) }))

        case let .doubleArray(arr):
            return .arrayValue(OTLPArrayValue(values: arr.map { .doubleValue($0) }))

        case let .set(set):
            let kvList = set.labels.map { key, attrValue in
                OTLPKeyValue(key: key, value: convertAttributeValue(attrValue))
            }
            return .kvlistValue(OTLPKeyValueList(values: kvList))

        case let .array(arr):
            return .arrayValue(OTLPArrayValue(values: arr.values.map { convertAttributeValue($0) }))
        }
    }

    /// Converts span events to OTLPSpanEvent array.
    private static func convertEvents(_ events: [SpanData.Event]) -> [OTLPSpanEvent]? {
        guard !events.isEmpty else {
            return nil
        }

        return events.map { event in
            OTLPSpanEvent(
                timeUnixNano: OTLPUInt64(event.timestamp.timeIntervalSince1970.toNanoseconds),
                name: event.name,
                attributes: convertAttributes(event.attributes),
                droppedAttributesCount: nil // SDK doesn't track this per event
            )
        }
    }

    /// Converts span links to OTLPSpanLink array.
    private static func convertLinks(_ links: [SpanData.Link]) -> [OTLPSpanLink]? {
        guard !links.isEmpty else {
            return nil
        }

        return links.map { link in
            OTLPSpanLink(
                traceId: OTLPTraceId(from: link.context.traceId),
                spanId: OTLPSpanId(from: link.context.spanId),
                traceState: link.context.traceState.entries.isEmpty ? nil : traceStateToString(link.context.traceState),
                attributes: convertAttributes(link.attributes),
                droppedAttributesCount: nil, // SDK doesn't track this per link
                flags: UInt32(link.context.traceFlags.byte)
            )
        }
    }

    /// Converts span status to OTLPStatus.
    private static func convertStatus(_ status: Status) -> OTLPStatus? {
        // Only include status if it's not unset
        switch status {
        case .unset:
            return nil

        case .ok:
            return OTLPStatus(message: nil, code: OTLPStatus.ok)

        case let .error(description):
            return OTLPStatus(message: description, code: OTLPStatus.error)
        }
    }

    /// Calculates dropped count from total and actual counts.
    private static func calculateDroppedCount(total: Int, actual: Int) -> UInt32? {
        let dropped = total - actual
        return dropped > 0 ? UInt32(dropped) : nil
    }
}


// MARK: - TimeInterval Extension

extension TimeInterval {
    /// Converts TimeInterval (seconds since 1970) to nanoseconds.
    var toNanoseconds: UInt64 {
        UInt64(self * 1_000_000_000)
    }
}
