// swiftlint:disable all
// swiftformat:disable all

// Changes made:
// - prefix filename
// - prefix enum name
// - import OpenTelemetryProtocolExporterCommon
// - use SplunkAttributeValue intead of AttributeValue
// - add Data cases
// - enum and methods internal
// - disable linters

/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon

enum SplunkCommonAdapter {
    static func toProtoAttribute(key: String, attributeValue: SplunkAttributeValue)
    -> Opentelemetry_Proto_Common_V1_KeyValue {
        var keyValue = Opentelemetry_Proto_Common_V1_KeyValue()
        keyValue.key = key
        switch attributeValue {
        case let .string(value):
            keyValue.value.stringValue = value
        case let .bool(value):
            keyValue.value.boolValue = value
        case let .int(value):
            keyValue.value.intValue = Int64(value)
        case let .double(value):
            keyValue.value.doubleValue = value
        case let .data(value):
            keyValue.value.bytesValue = value
        case let .set(value):
            keyValue.value.kvlistValue.values = value.labels.map {
                return toProtoAttribute(key: $0, attributeValue: SplunkAttributeValue(otelAttributeValue: $1))
            }
        case let .array(value):
            keyValue.value.arrayValue.values = value.values.map {
                return toProtoAnyValue(attributeValue: SplunkAttributeValue(otelAttributeValue: $0))
            }
        case let .stringArray(value):
            keyValue.value.arrayValue.values = value.map {
                return toProtoAnyValue(attributeValue: .string($0))
            }
        case let .boolArray(value):
            keyValue.value.arrayValue.values = value.map {
                return toProtoAnyValue(attributeValue: .bool($0))
            }
        case let .intArray(value):
            keyValue.value.arrayValue.values = value.map {
                return toProtoAnyValue(attributeValue: .int($0))
            }
        case let .doubleArray(value):
            keyValue.value.arrayValue.values = value.map {
                return toProtoAnyValue(attributeValue: .double($0))
            }
        }
        return keyValue
    }
    
    static func toProtoAnyValue(attributeValue: SplunkAttributeValue) -> Opentelemetry_Proto_Common_V1_AnyValue {
        var anyValue = Opentelemetry_Proto_Common_V1_AnyValue()
        switch attributeValue {
        case let .string(value):
            anyValue.stringValue = value
        case let .bool(value):
            anyValue.boolValue = value
        case let .int(value):
            anyValue.intValue = Int64(value)
        case let .double(value):
            anyValue.doubleValue = value
        case let .data(value):
            anyValue.bytesValue = value
        case let .set(value):
            anyValue.kvlistValue.values = value.labels.map {
                return toProtoAttribute(key: $0, attributeValue: SplunkAttributeValue(otelAttributeValue: $1))
            }
        case let .array(value):
            anyValue.arrayValue.values = value.values.map {
                return toProtoAnyValue(attributeValue: SplunkAttributeValue(otelAttributeValue: $0))
            }
        case let .stringArray(value):
            anyValue.arrayValue.values = value.map {
                return toProtoAnyValue(attributeValue: .string($0))
            }
        case let .boolArray(value):
            anyValue.arrayValue.values = value.map {
                return toProtoAnyValue(attributeValue: .bool($0))
            }
        case let .intArray(value):
            anyValue.arrayValue.values = value.map {
                return toProtoAnyValue(attributeValue: .int($0))
            }
        case let .doubleArray(value):
            anyValue.arrayValue.values = value.map {
                return toProtoAnyValue(attributeValue: .double($0))
            }
        }
        return anyValue
    }
    
    static func toProtoInstrumentationScope(instrumentationScopeInfo: InstrumentationScopeInfo)
    -> Opentelemetry_Proto_Common_V1_InstrumentationScope {
        var instrumentationScope = Opentelemetry_Proto_Common_V1_InstrumentationScope()
        instrumentationScope.name = instrumentationScopeInfo.name
        if let version = instrumentationScopeInfo.version {
            instrumentationScope.version = version
        }
        return instrumentationScope
    }
}

// swiftformat:enable all
// swiftlint:enable all
