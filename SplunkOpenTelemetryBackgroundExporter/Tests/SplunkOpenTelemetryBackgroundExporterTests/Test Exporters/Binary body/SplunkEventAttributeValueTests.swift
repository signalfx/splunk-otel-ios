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
import SplunkCommon
import Testing
@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct SplunkEventAttributeValueTests {

    // MARK: - String

    @Test
    func mapsString() {
        let event: EventAttributeValue = .string("hello")
        let mapped = SplunkAttributeValue(eventAttributeValue: event)
        #expect(mapped == .string("hello"))
    }


    // MARK: - Int

    @Test
    func mapsIntPositive() {
        let event: EventAttributeValue = .int(123)
        let mapped = SplunkAttributeValue(eventAttributeValue: event)
        #expect(mapped == .int(123))
    }

    @Test
    func mapsIntNegative() {
        let event: EventAttributeValue = .int(-999)
        let mapped = SplunkAttributeValue(eventAttributeValue: event)
        #expect(mapped == .int(-999))
    }


    // MARK: - Double

    @Test
    func mapsDouble() {
        let event: EventAttributeValue = .double(3.14159)
        let mapped = SplunkAttributeValue(eventAttributeValue: event)
        #expect(mapped == .double(3.14159))
    }


    // MARK: - Data

    @Test
    func mapsDataNonEmpty() {
        let bytes = Data([0x00, 0xFF, 0x10, 0x20])
        let event: EventAttributeValue = .data(bytes)
        let mapped = SplunkAttributeValue(eventAttributeValue: event)
        #expect(mapped == .data(bytes))
    }

    @Test
    func mapsDataEmpty() {
        let bytes = Data()
        let event: EventAttributeValue = .data(bytes)
        let mapped = SplunkAttributeValue(eventAttributeValue: event)
        #expect(mapped == .data(bytes))
    }
}
