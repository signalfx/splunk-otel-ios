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
struct SplunkAttributeValueTests {

    // MARK: - Failable init(Any)

    @Test
    func initAnySupportsScalars() {
        #expect(SplunkAttributeValue("hello") == .string("hello"))
        #expect(SplunkAttributeValue("hello" as Any) == .string("hello"))

        #expect(SplunkAttributeValue(true) == .bool(true))
        #expect(SplunkAttributeValue(true as Any) == .bool(true))

        #expect(SplunkAttributeValue(123) == .int(123))
        #expect(SplunkAttributeValue(123 as Any) == .int(123))

        #expect(SplunkAttributeValue(3.5) == .double(3.5))
        #expect(SplunkAttributeValue(3.5 as Any) == .double(3.5))

        let bytes = Data([0x00, 0xFF])
        #expect(SplunkAttributeValue(bytes) == .data(bytes))

        #expect(SplunkAttributeValue(bytes as Any) == .data(bytes))
    }

    @Test
    func initPrimitiveSupportsPrimitiveArrays() {
        let stringsArray = SplunkAttributeValue(["a", "b"])
        let boolsArray = SplunkAttributeValue([true, false])
        let intArray = SplunkAttributeValue([1, 2, 3])
        let doubleArray = SplunkAttributeValue([1.5, 2.5])

        guard case let .array(sa) = stringsArray else {
            #expect(Bool(false), "Expected .array for [String]")

            return
        }

        guard case let .array(ba) = boolsArray else {
            #expect(Bool(false), "Expected .array for [Bool]")

            return
        }

        guard case let .array(ia) = intArray else {
            #expect(Bool(false), "Expected .array for [Int]")

            return
        }

        guard case let .array(da) = doubleArray else {
            #expect(Bool(false), "Expected .array for [Double]")

            return
        }

        #expect(sa.values == [.string("a"), .string("b")])
        #expect(ba.values == [.bool(true), .bool(false)])
        #expect(ia.values == [.int(1), .int(2), .int(3)])
        #expect(da.values == [.double(1.5), .double(2.5)])
    }

    @Test
    func initAnySupportsPrimitiveArrays() {
        let stringsArray = SplunkAttributeValue(["a", "b"] as Any)
        let boolsArray = SplunkAttributeValue([true, false] as Any)
        let intArray = SplunkAttributeValue([1, 2, 3] as Any)
        let doubleArray = SplunkAttributeValue([1.5, 2.5] as Any)

        guard case let .array(sa) = stringsArray else {
            #expect(Bool(false), "Expected .array for [String]")

            return
        }

        guard case let .array(ba) = boolsArray else {
            #expect(Bool(false), "Expected .array for [Bool]")

            return
        }

        guard case let .array(ia) = intArray else {
            #expect(Bool(false), "Expected .array for [Int]")

            return
        }

        guard case let .array(da) = doubleArray else {
            #expect(Bool(false), "Expected .array for [Double]")

            return
        }

        #expect(sa.values == [.string("a"), .string("b")])
        #expect(ba.values == [.bool(true), .bool(false)])
        #expect(ia.values == [.int(1), .int(2), .int(3)])
        #expect(da.values == [.double(1.5), .double(2.5)])
    }

    @Test
    func initAnySupportsAttributeArrayAndSet() {
        let arr = AttributeArray(values: [.string("x"), .int(7)])
        let set = AttributeSet(labels: ["k1": .string("v1"), "k2": .int(10)])

        // Failable Any init
        let aFromAny = SplunkAttributeValue(arr as Any)
        let sFromAny = SplunkAttributeValue(set as Any)

        guard case let .array(mappedArrAny) = aFromAny else {
            #expect(Bool(false), "Expected .array (Any)")

            return
        }

        guard case let .set(mappedSetAny) = sFromAny else {
            #expect(Bool(false), "Expected .set (Any)")

            return
        }

        #expect(mappedArrAny.values == arr.values)
        #expect(mappedSetAny.labels == set.labels)

        // Typed init (already covered indirectly, but assert explicitly)
        let arrayttribute = SplunkAttributeValue(arr)
        let setAttribute = SplunkAttributeValue(set)

        guard case let .array(mappedArr) = arrayttribute else {
            #expect(Bool(false), "Expected .array")

            return
        }

        guard case let .set(mappedSet) = setAttribute else {
            #expect(Bool(false), "Expected .set")

            return
        }

        #expect(mappedArr.values == arr.values)
        #expect(mappedSet.labels == set.labels)
    }

    @Test
    func initAnyUnsupportedReturnsNil() {
        struct Unsupported {}
        let unsupported = Unsupported()
        #expect(SplunkAttributeValue(unsupported as Any) == nil)

        // Mixed-type array [Any] should also be unsupported
        let mixed: [Any] = ["s", 1]
        #expect(SplunkAttributeValue(mixed as Any) == nil)
    }


    // MARK: - CustomStringConvertible

    @Test
    func descriptionScalars() {
        #expect(SplunkAttributeValue.string("hello").description == "hello")
        #expect(SplunkAttributeValue.bool(true).description == "true")
        #expect(SplunkAttributeValue.bool(false).description == "false")
        #expect(SplunkAttributeValue.int(42).description == "42")
        #expect(SplunkAttributeValue.double(3.0).description == "3.0")

        // Data description format is not strictly specified; just ensure it's non-empty.
        let bytes = Data([0x01, 0x02])
        #expect(!SplunkAttributeValue.data(bytes).description.isEmpty)
    }

    @Test
    func descriptionArrayAndSet() {
        let arr = SplunkAttributeValue.array(AttributeArray(values: [.string("a"), .int(1)]))
        let set = SplunkAttributeValue.set(AttributeSet(labels: ["k": .string("v")]))

        #expect(arr.description.contains("a"))
        #expect(arr.description.contains("1"))
        #expect(set.description.contains("k"))
        #expect(set.description.contains("v"))
    }

    @Test
    func descriptionDeprecatedPrimitiveArrays() {
        let stringArray = SplunkAttributeValue.stringArray(["x", "y"])
        let boolArray = SplunkAttributeValue.boolArray([true, false])
        let intArray = SplunkAttributeValue.intArray([1, 2])
        let doubleArray = SplunkAttributeValue.doubleArray([1.0, 2.5])

        #expect(stringArray.description.contains("x") && stringArray.description.contains("y"))
        #expect(boolArray.description.contains("true") && boolArray.description.contains("false"))
        #expect(intArray.description.contains("1") && intArray.description.contains("2"))
        #expect(doubleArray.description.contains("1.0") && doubleArray.description.contains("2.5"))
    }


    // MARK: - Codable (explicit wrapper)

    @Test
    func codableRoundTripString() throws {
        try roundTrip(.string("hello"))
    }

    @Test
    func codableRoundTripBool() throws {
        try roundTrip(.bool(true))
    }

    @Test
    func codableRoundTripInt() throws {
        try roundTrip(.int(123))
    }

    @Test
    func codableRoundTripDouble() throws {
        try roundTrip(.double(2.25))
    }

    @Test
    func codableRoundTripData() throws {
        try roundTrip(.data(Data([0x00, 0xFF, 0x10])))
    }

    @Test
    func codableRoundTripArray() throws {
        let arr = AttributeArray(values: [.string("x"), .int(7), .bool(false), .double(1.5)])
        try roundTrip(.array(arr))
    }

    @Test
    func codableRoundTripSet() throws {
        let set = AttributeSet(labels: ["a": .string("b"), "n": .int(1)])
        try roundTrip(.set(set))
    }

    private func roundTrip(_ value: SplunkAttributeValue) throws {
        let wrapper = SplunkAttributeValueExplicitCodable(attributeValue: value)
        let data = try JSONEncoder().encode(wrapper)
        let decoded = try JSONDecoder().decode(SplunkAttributeValueExplicitCodable.self, from: data)

        #expect(decoded.attributeValue == value)
    }


    // MARK: - Hashable / Equatable

    @Test
    func equalityAndHashable() {
        let aValue1 = SplunkAttributeValue.string("same")
        let aValue2 = SplunkAttributeValue.string("same")
        let bValue = SplunkAttributeValue.string("other")

        #expect(aValue1 == aValue2)
        #expect(aValue1 != bValue)

        var set = Set<SplunkAttributeValue>()
        set.insert(aValue1)
        set.insert(aValue2) // should not create a duplicate
        set.insert(bValue)

        #expect(set.count == 2)
        #expect(set.contains(aValue1))
        #expect(set.contains(bValue))
    }

    @Test
    func equalityArrayAndSet() {
        let arr1 = SplunkAttributeValue.array(AttributeArray(values: [.string("x"), .int(1)]))
        let arr2 = SplunkAttributeValue.array(AttributeArray(values: [.string("x"), .int(1)]))
        let arr3 = SplunkAttributeValue.array(AttributeArray(values: [.string("x"), .int(2)]))

        #expect(arr1 == arr2)
        #expect(arr1 != arr3)

        let set1 = SplunkAttributeValue.set(AttributeSet(labels: ["k": .string("v")]))
        let set2 = SplunkAttributeValue.set(AttributeSet(labels: ["k": .string("v")]))
        let set3 = SplunkAttributeValue.set(AttributeSet(labels: ["k": .string("w")]))

        #expect(set1 == set2)
        #expect(set1 != set3)
    }

    @Test
    func equalityData() {
        let d1 = Data([0x01, 0x02, 0x03])
        let d2 = Data([0x01, 0x02, 0x03])
        let d3 = Data([0x01, 0x02, 0x04])

        #expect(SplunkAttributeValue.data(d1) == .data(d2))
        #expect(SplunkAttributeValue.data(d1) != .data(d3))
    }
}
