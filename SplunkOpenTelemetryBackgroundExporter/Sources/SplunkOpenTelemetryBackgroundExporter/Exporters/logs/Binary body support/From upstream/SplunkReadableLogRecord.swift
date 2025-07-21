// swiftlint:disable all
// swiftformat:disable all

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

/// A struct that provides a readable representation of a log record, adapted for Splunk's needs.
///
/// This data structure holds all the information for a single log event, including its timestamp, severity,
/// body, and associated attributes. It is designed to be easily serializable and exportable.
public struct SplunkReadableLogRecord: Codable {
  /// Initializes a new `SplunkReadableLogRecord`.
  /// - Parameters:
  ///   - resource: The resource associated with this log.
  ///   - instrumentationScopeInfo: The instrumentation scope that generated this log.
  ///   - timestamp: The time when the event occurred.
  ///   - observedTimestamp: The time when the log was observed. Defaults to `nil`.
  ///   - spanContext: The span context associated with this log, if any. Defaults to `nil`.
  ///   - severity: The severity level of the log. Defaults to `nil`.
  ///   - body: The main content or message of the log. Defaults to `nil`.
  ///   - attributes: A dictionary of key-value pairs with additional information.
  public init(resource: Resource, instrumentationScopeInfo: InstrumentationScopeInfo, timestamp: Date, observedTimestamp: Date? = nil, spanContext: SpanContext? = nil, severity: Severity? = nil, body: SplunkAttributeValue? = nil, attributes: [String: SplunkAttributeValue]) {
    self.resource = resource
    self.instrumentationScopeInfo = instrumentationScopeInfo
    self.timestamp = timestamp
    self.observedTimestamp = observedTimestamp
    self.spanContext = spanContext
    self.severity = severity
    self.body = body
    self.attributes = attributes
  }

  /// The resource associated with this log record.
  public private(set) var resource: Resource
  /// The instrumentation scope that emitted this log.
  public private(set) var instrumentationScopeInfo: InstrumentationScopeInfo
  /// The timestamp of when the log event occurred.
  public private(set) var timestamp: Date
  /// The timestamp of when the log was observed by the collection system.
  public private(set) var observedTimestamp: Date?
  /// The `SpanContext` associated with this log, linking it to a trace.
  public private(set) var spanContext: SpanContext?
  /// The severity level of the log message.
  public private(set) var severity: Severity?
  /// The body of the log record, which can be of various types.
  public var body: SplunkAttributeValue?
  /// A collection of key-value attributes associated with the log record.
  public var attributes: [String: SplunkAttributeValue]
}

// swiftlint:enable all
// swiftformat:enable all
