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
import Testing

@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct SplunkAttributeValueAttributeValueTests {

    // MARK: - Scalars

    @Test
    func mapsString() {
        let otel: AttributeValue = .string("hello")
        let mapped = SplunkAttributeValue(otelAttributeValue: otel)
        #expect(mapped == .string("hello"))
    }

    @Test
    func mapsBool() {
        let otel: AttributeValue = .bool(true)
        let mapped = SplunkAttributeValue(otelAttributeValue: otel)
        #expect(mapped == .bool(true))
    }

    @Test
    func mapsInt() {
        let otel: AttributeValue = .int(42)
        let mapped = SplunkAttributeValue(otelAttributeValue: otel)
        #expect(mapped == .int(42))
    }

    @Test
    func mapsDouble() {
        let otel: AttributeValue = .double(3.14159)
        let mapped = SplunkAttributeValue(otelAttributeValue: otel)
        #expect(mapped == .double(3.14159))
    }


    // MARK: - Arrays of primitives

    @Test
    func mapsStringArrayToArrayAttribute() {
        let otel: AttributeValue = .stringArray(["a", "b"])
        let mapped = SplunkAttributeValue(otelAttributeValue: otel)

        guard case let .array(arr) = mapped else {
            #expect(Bool(false), "Expected .array case")
            return
        }

        #expect(arr.values == [.string("a"), .string("b")])
    }

    @Test
    func mapsBoolArrayToArrayAttribute() {
        let otel: AttributeValue = .boolArray([true, false])
        let mapped = SplunkAttributeValue(otelAttributeValue: otel)

        guard case let .array(arr) = mapped else {
            #expect(Bool(false), "Expected .array case")
            return
        }

        #expect(arr.values == [.bool(true), .bool(false)])
    }

    @Test
    func mapsIntArrayToArrayAttribute() {
        let otel: AttributeValue = .intArray([1, 2, 3])
        let mapped = SplunkAttributeValue(otelAttributeValue: otel)

        guard case let .array(arr) = mapped else {
            #expect(Bool(false), "Expected .array case")
            return
        }

        #expect(arr.values == [.int(1), .int(2), .int(3)])
    }

    @Test
    func mapsDoubleArrayToArrayAttribute() {
        let otel: AttributeValue = .doubleArray([1.5, 2.5])
        let mapped = SplunkAttributeValue(otelAttributeValue: otel)

        guard case let .array(arr) = mapped else {
            #expect(Bool(false), "Expected .array case")
            return
        }

        #expect(arr.values == [.double(1.5), .double(2.5)])
    }


    // MARK: - AttributeArray (mixed types)

    @Test
    func mapsAttributeArrayPreservesElements() {
        let array = AttributeArray(values: [
            .string("x"),
            .int(7),
            .double(2.25),
            .bool(false)
        ])
        let otel: AttributeValue = .array(array)

        let mapped = SplunkAttributeValue(otelAttributeValue: otel)

        guard case let .array(arr) = mapped else {
            #expect(Bool(false), "Expected .array case")
            return
        }

        #expect(arr.values == array.values)
    }

    @Test
    func mapsEmptyAttributeArray() {
        let array = AttributeArray(values: [])
        let otel: AttributeValue = .array(array)

        let mapped = SplunkAttributeValue(otelAttributeValue: otel)

        guard case let .array(arr) = mapped else {
            #expect(Bool(false), "Expected .array case")
            return
        }

        #expect(arr.values.isEmpty)
    }


    // MARK: - AttributeSet

    @Test
    func mapsAttributeSetPreservesLabels() {
        let set = AttributeSet(labels: [
            "k1": .string("v1"),
            "k2": .int(10),
            "k3": .bool(true)
        ])
        let otel: AttributeValue = .set(set)

        let mapped = SplunkAttributeValue(otelAttributeValue: otel)

        guard case let .set(mappedSet) = mapped else {
            #expect(Bool(false), "Expected .set case")
            return
        }

        #expect(mappedSet.labels == set.labels)
    }

    @Test
    func mapsEmptyAttributeSet() {
        let set = AttributeSet(labels: [:])
        let otel: AttributeValue = .set(set)

        let mapped = SplunkAttributeValue(otelAttributeValue: otel)

        guard case let .set(mappedSet) = mapped else {
            #expect(Bool(false), "Expected .set case")
            return
        }

        #expect(mappedSet.labels.isEmpty)
    }
}
