//
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
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk
import Testing

@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct SplunkCommonAdapterTests {

    // MARK: - toProtoAttribute: Scalars and Data

    @Test
    func toProtoAttributeMapsScalarsAndData() {
        let key = "k"

        let stringValue = SplunkCommonAdapter.toProtoAttribute(key: key, attributeValue: .string("hello"))
        #expect(stringValue.key == key)
        #expect(stringValue.value.stringValue == "hello")

        let boolValue = SplunkCommonAdapter.toProtoAttribute(key: key, attributeValue: .bool(true))
        #expect(boolValue.value.boolValue == true)

        let intValue = SplunkCommonAdapter.toProtoAttribute(key: key, attributeValue: .int(42))
        #expect(intValue.value.intValue == 42)

        let doubleValue = SplunkCommonAdapter.toProtoAttribute(key: key, attributeValue: .double(3.14))
        #expect(doubleValue.value.doubleValue == 3.14)

        let bytes = Data([0x00, 0xFF, 0x10, 0x20])
        let dataKV = SplunkCommonAdapter.toProtoAttribute(key: key, attributeValue: .data(bytes))
        #expect(dataKV.value.bytesValue == bytes)
    }


    // MARK: - toProtoAttribute: Array (mixed and deprecated)

    @Test
    func toProtoAttributeMapsArrayMixed() {
        let mixed = AttributeArray(values: [
            .string("a"),
            .bool(false),
            .int(7),
            .double(2.5)
        ])

        let kv = SplunkCommonAdapter.toProtoAttribute(key: "arr", attributeValue: .array(mixed))
        let values = kv.value.arrayValue.values

        #expect(values.count == 4)
        #expect(values[0].stringValue == "a")
        #expect(values[1].boolValue == false)
        #expect(values[2].intValue == 7)
        #expect(values[3].doubleValue == 2.5)
    }

    @Test
    func toProtoAttributeMapsDeprecatedPrimitiveArrays() {
        let stringValue = SplunkCommonAdapter.toProtoAttribute(key: "s", attributeValue: .stringArray(["x", "y"]))
        #expect(stringValue.value.arrayValue.values.map(\.stringValue) == ["x", "y"])

        let boolValue = SplunkCommonAdapter.toProtoAttribute(key: "b", attributeValue: .boolArray([true, false]))
        #expect(boolValue.value.arrayValue.values.map(\.boolValue) == [true, false])

        let intValue = SplunkCommonAdapter.toProtoAttribute(key: "i", attributeValue: .intArray([1, 2, 3]))
        #expect(intValue.value.arrayValue.values.map(\.intValue) == [1, 2, 3])

        let doubleValue = SplunkCommonAdapter.toProtoAttribute(key: "d", attributeValue: .doubleArray([1.0, 2.5]))
        #expect(doubleValue.value.arrayValue.values.map(\.doubleValue) == [1.0, 2.5])
    }

    @Test
    func toProtoAttributeMapsArrayWithNestedStructures() {
        let inner = AttributeArray(values: [
            .string("inner"),
            .int(99)
        ])
        let outer = AttributeArray(values: [
            .array(inner),
            .bool(true)
        ])

        let kv = SplunkCommonAdapter.toProtoAttribute(key: "nested", attributeValue: .array(outer))
        let outValues = kv.value.arrayValue.values
        #expect(outValues.count == 2)

        // First element is an array AnyValue
        let first = outValues[0]
        let innerValues = first.arrayValue.values
        #expect(innerValues.count == 2)
        #expect(innerValues[0].stringValue == "inner")
        #expect(innerValues[1].intValue == 99)

        // Second element is a bool AnyValue
        #expect(outValues[1].boolValue == true)
    }


    // MARK: - toProtoAttribute: Set

    @Test
    func toProtoAttributeMapsSetToKVList() {
        let set = AttributeSet(labels: [
            "k1": .string("v1"),
            "k2": .int(10),
            "k3": .bool(false),
            "k4": .double(2.75)
        ])

        let kv = SplunkCommonAdapter.toProtoAttribute(key: "set", attributeValue: .set(set))
        let entries = kv.value.kvlistValue.values

        // Build a dictionary for easier assertions
        var dict: [String: Opentelemetry_Proto_Common_V1_AnyValue] = [:]
        for entry in entries {
            dict[entry.key] = entry.value
        }

        #expect(dict["k1"]?.stringValue == "v1")
        #expect(dict["k2"]?.intValue == 10)
        #expect(dict["k3"]?.boolValue == false)
        #expect(dict["k4"]?.doubleValue == 2.75)
    }


    // MARK: - toProtoAnyValue: Scalars, Data, Array, Set

    @Test
    func toProtoAnyValueMapsScalarsAndData() {
        #expect(SplunkCommonAdapter.toProtoAnyValue(attributeValue: .string("s")).stringValue == "s")
        #expect(SplunkCommonAdapter.toProtoAnyValue(attributeValue: .bool(true)).boolValue == true)
        #expect(SplunkCommonAdapter.toProtoAnyValue(attributeValue: .int(5)).intValue == 5)
        #expect(SplunkCommonAdapter.toProtoAnyValue(attributeValue: .double(1.25)).doubleValue == 1.25)

        let bytes = Data([0xAA, 0xBB])
        #expect(SplunkCommonAdapter.toProtoAnyValue(attributeValue: .data(bytes)).bytesValue == bytes)
    }

    @Test
    func toProtoAnyValueMapsArrayMixedAndDeprecated() {
        let mixed = AttributeArray(values: [
            .string("x"),
            .int(1),
            .bool(true),
            .double(2.0)
        ])

        let anyMixed = SplunkCommonAdapter.toProtoAnyValue(attributeValue: .array(mixed))
        let mv = anyMixed.arrayValue.values
        #expect(mv.count == 4)
        #expect(mv[0].stringValue == "x")
        #expect(mv[1].intValue == 1)
        #expect(mv[2].boolValue == true)
        #expect(mv[3].doubleValue == 2.0)

        let depS = SplunkCommonAdapter.toProtoAnyValue(attributeValue: .stringArray(["a", "b"]))
        #expect(depS.arrayValue.values.map(\.stringValue) == ["a", "b"])

        let depB = SplunkCommonAdapter.toProtoAnyValue(attributeValue: .boolArray([false, true]))
        #expect(depB.arrayValue.values.map(\.boolValue) == [false, true])

        let depI = SplunkCommonAdapter.toProtoAnyValue(attributeValue: .intArray([7, 8]))
        #expect(depI.arrayValue.values.map(\.intValue) == [7, 8])

        let depD = SplunkCommonAdapter.toProtoAnyValue(attributeValue: .doubleArray([0.5, 1.5]))
        #expect(depD.arrayValue.values.map(\.doubleValue) == [0.5, 1.5])
    }

    @Test
    func toProtoAnyValueMapsNestedArrayAndSet() {
        let inner = AttributeArray(values: [.string("in"), .int(2)])
        let outer = AttributeArray(values: [.array(inner), .bool(false)])
        let set = AttributeSet(labels: ["a": .string("b"), "n": .int(3)])

        let anyArr = SplunkCommonAdapter.toProtoAnyValue(attributeValue: .array(outer))
        #expect(anyArr.arrayValue.values.count == 2)
        #expect(anyArr.arrayValue.values[0].arrayValue.values[0].stringValue == "in")
        #expect(anyArr.arrayValue.values[0].arrayValue.values[1].intValue == 2)
        #expect(anyArr.arrayValue.values[1].boolValue == false)

        let anySet = SplunkCommonAdapter.toProtoAnyValue(attributeValue: .set(set))
        // Convert kvlist to dict
        var dict: [String: Opentelemetry_Proto_Common_V1_AnyValue] = [:]
        for kv in anySet.kvlistValue.values {
            dict[kv.key] = kv.value
        }
        #expect(dict["a"]?.stringValue == "b")
        #expect(dict["n"]?.intValue == 3)
    }


    // MARK: - toProtoInstrumentationScope

    @Test
    func toProtoInstrumentationScopeMapsNameAndVersion() {
        let scope = InstrumentationScopeInfo(name: "lib", version: "1.2.3")
        let proto = SplunkCommonAdapter.toProtoInstrumentationScope(instrumentationScopeInfo: scope)

        #expect(proto.name == "lib")
        #expect(proto.version == "1.2.3")
    }

    @Test
    func toProtoInstrumentationScopeWithoutVersionLeavesDefault() {
        let scope = InstrumentationScopeInfo(name: "lib", version: nil)
        let proto = SplunkCommonAdapter.toProtoInstrumentationScope(instrumentationScopeInfo: scope)

        #expect(proto.name == "lib")
        // Version is set only if non-nil; default for proto3 string is empty
        #expect(proto.version.isEmpty)
    }
}
