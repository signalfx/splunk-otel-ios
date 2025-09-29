// Changes made:
// - prefix filename
// - prefix struct name
// - import OpenTelemetrySdk
// - use SplunkAttributeValue intead of AttributeValue
// - make setters public
// - disable linters

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public struct SplunkReadableLogRecord: Codable {
    public init(
        resource: Resource,
        instrumentationScopeInfo: InstrumentationScopeInfo,
        timestamp: Date,
        observedTimestamp: Date? = nil,
        spanContext: SpanContext? = nil,
        severity: Severity? = nil,
        body: SplunkAttributeValue? = nil,
        attributes: [String: SplunkAttributeValue]
    ) {
        self.resource = resource
        self.instrumentationScopeInfo = instrumentationScopeInfo
        self.timestamp = timestamp
        self.observedTimestamp = observedTimestamp
        self.spanContext = spanContext
        self.severity = severity
        self.body = body
        self.attributes = attributes
    }

    public private(set) var resource: Resource
    public private(set) var instrumentationScopeInfo: InstrumentationScopeInfo
    public private(set) var timestamp: Date
    public private(set) var observedTimestamp: Date?
    public private(set) var spanContext: SpanContext?
    public private(set) var severity: Severity?
    public var body: SplunkAttributeValue?
    public var attributes: [String: SplunkAttributeValue]
}
