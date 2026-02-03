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
import Testing

@testable import SplunkOpenTelemetry


@Suite
struct SpanDataIsolatedCopyTests {

    // MARK: - Helpers

    /// Creates a SpanData instance by using a real tracer and span.
    private func makeSpanData(
        name: String = "test-span",
        attributes: [String: AttributeValue] = [:],
        events: [(name: String, attributes: [String: AttributeValue])] = [],
        links: [SpanContext] = []
    ) -> SpanData {
        // Create a tracer provider with a no-op exporter
        let exporter = NoOpSpanExporter()
        let processor = SimpleSpanProcessor(spanExporter: exporter)
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .build()

        let tracer = tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0")

        // Build the span with links
        var spanBuilder = tracer.spanBuilder(spanName: name)
        for linkContext in links {
            spanBuilder = spanBuilder.addLink(spanContext: linkContext)
        }

        let span = spanBuilder.startSpan()

        // Add attributes
        for (key, value) in attributes {
            span.setAttribute(key: key, value: value)
        }

        // Add events
        for event in events {
            span.addEvent(name: event.name, attributes: event.attributes)
        }

        span.end()

        // Get the SpanData from the span
        if let readableSpan = span as? ReadableSpan {
            return readableSpan.toSpanData()
        }

        fatalError("Could not get SpanData from span")
    }

    /// Creates a SpanContext for use in links.
    private func makeSpanContext() -> SpanContext {
        SpanContext.create(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            traceFlags: TraceFlags(),
            traceState: TraceState()
        )
    }


    // MARK: - Basic Copy Tests

    @Test
    func isolatedCopyPreservesAllFields() {
        let attributes: [String: AttributeValue] = [
            "string": .string("value"),
            "int": .int(42),
            "bool": .bool(true)
        ]
        let events = [
            (name: "event1", attributes: ["eventAttr": AttributeValue.string("eventValue")])
        ]
        let linkContext = makeSpanContext()

        let original = makeSpanData(
            attributes: attributes,
            events: events,
            links: [linkContext]
        )
        let copy = original.isolatedCopy()

        // Verify all fields are preserved
        #expect(copy.traceId == original.traceId)
        #expect(copy.spanId == original.spanId)
        #expect(copy.name == original.name)
        #expect(copy.kind == original.kind)
        #expect(copy.startTime == original.startTime)
        #expect(copy.endTime == original.endTime)

        // Verify attributes are preserved
        #expect(copy.attributes.count == original.attributes.count)
        #expect(copy.attributes["string"]?.description == "value")
        #expect(copy.attributes["int"]?.description == "42")
        #expect(copy.attributes["bool"]?.description == "true")

        // Verify events are preserved
        #expect(copy.events.count == original.events.count)
        #expect(copy.events.first?.name == "event1")
        #expect(copy.events.first?.attributes["eventAttr"]?.description == "eventValue")

        // Verify links are preserved
        #expect(copy.links.count == original.links.count)
        #expect(copy.links.first?.context.traceId == linkContext.traceId)
    }

    @Test
    func isolatedCopyHandlesEmptySpanData() {
        let original = makeSpanData()
        let copy = original.isolatedCopy()

        #expect(copy.attributes.isEmpty)
        #expect(copy.events.isEmpty)
        #expect(copy.links.isEmpty)
        #expect(copy.name == original.name)
    }

    @Test
    func isolatedCopyCreatesIndependentAttributes() {
        let attributes: [String: AttributeValue] = [
            "key1": .string("value1"),
            "key2": .string("value2")
        ]
        let original = makeSpanData(attributes: attributes)
        var copy = original.isolatedCopy()

        // Modify the copy's attributes
        copy = copy.settingAttributes(["key1": .string("modified")])

        // Original should be unchanged
        #expect(original.attributes["key1"]?.description == "value1")
        #expect(copy.attributes["key1"]?.description == "modified")
    }


    // MARK: - Deep Isolation Tests

    @Test
    func isolatedCopyCreatesIndependentEventAttributes() {
        // Create span with events that have attributes
        let events = [
            (name: "test-event", attributes: ["eventKey": AttributeValue.string("eventValue")])
        ]
        let original = makeSpanData(events: events)
        var copy = original.isolatedCopy()

        // Verify both have the same event data initially
        #expect(original.events.first?.attributes["eventKey"]?.description == "eventValue")
        #expect(copy.events.first?.attributes["eventKey"]?.description == "eventValue")

        // Modify the copy's events to prove independence
        let modifiedEvents = [
            SpanData.Event(
                name: "modified-event",
                timestamp: Date(),
                attributes: ["eventKey": .string("modifiedValue"), "newKey": .string("newValue")]
            )
        ]
        copy = copy.settingEvents(modifiedEvents)

        // Original should be unchanged
        #expect(original.events.first?.name == "test-event")
        #expect(original.events.first?.attributes["eventKey"]?.description == "eventValue")
        #expect(original.events.first?.attributes["newKey"] == nil)

        // Copy should have the modifications
        #expect(copy.events.first?.name == "modified-event")
        #expect(copy.events.first?.attributes["eventKey"]?.description == "modifiedValue")
        #expect(copy.events.first?.attributes["newKey"]?.description == "newValue")
    }

    @Test
    func isolatedCopyCreatesIndependentLinkAttributes() {
        // Create span with links that have attributes
        let linkContext = makeSpanContext()
        let original = makeSpanData(links: [linkContext])
        var copy = original.isolatedCopy()

        // Verify both have the same link data initially
        #expect(original.links.first?.context.traceId == linkContext.traceId)
        #expect(copy.links.first?.context.traceId == linkContext.traceId)
        #expect(original.links.count == 1)

        // Modify the copy's links to prove independence
        let newLinkContext = makeSpanContext()
        let modifiedLinks = [
            SpanData.Link(context: newLinkContext, attributes: ["linkAttr": .string("linkValue")])
        ]
        copy = copy.settingLinks(modifiedLinks)

        // Original should be unchanged
        #expect(original.links.first?.context.traceId == linkContext.traceId)
        #expect(original.links.first?.attributes.isEmpty == true)

        // Copy should have the modifications
        #expect(copy.links.first?.context.traceId == newLinkContext.traceId)
        #expect(copy.links.first?.attributes["linkAttr"]?.description == "linkValue")
    }

    @Test
    func isolatedCopyCreatesIndependentResourceAttributes() {
        // Create span - resources are automatically added by the tracer
        let original = makeSpanData(attributes: ["test": .string("value")])
        let copy = original.isolatedCopy()

        // Both should have resource attributes (at minimum the SDK defaults)
        #expect(!original.resource.attributes.isEmpty)
        #expect(!copy.resource.attributes.isEmpty)

        // The resource attributes should have the same content
        #expect(copy.resource.attributes.count == original.resource.attributes.count)

        // Verify all resource attributes are preserved
        for (key, value) in original.resource.attributes {
            #expect(copy.resource.attributes[key]?.description == value.description)
        }
    }

    @Test
    func isolatedCopyResourceAttributesAreFullyIndependent() {
        // This test verifies that modifying the copy's resource doesn't affect the original
        let original = makeSpanData()
        var copy = original.isolatedCopy()

        // Get original resource attribute count
        let originalResourceCount = original.resource.attributes.count

        // Create a new resource with additional attributes for the copy
        var newResourceAttrs = copy.resource.attributes
        newResourceAttrs["new.attribute"] = .string("new-value")
        copy = copy.settingResource(Resource(attributes: newResourceAttrs))

        // Original resource should be unchanged
        #expect(original.resource.attributes.count == originalResourceCount)
        #expect(original.resource.attributes["new.attribute"] == nil)

        // Copy should have the new attribute
        #expect(copy.resource.attributes["new.attribute"]?.description == "new-value")
    }


    // MARK: - Concurrent Access Tests

    @Test
    func isolatedCopySurvivesConcurrentAccess() async {
        let attributes: [String: AttributeValue] = [
            "attr1": .string("value1"),
            "attr2": .int(100),
            "attr3": .bool(true)
        ]
        let events = [
            (name: "event", attributes: ["key": AttributeValue.string("val")])
        ]
        let original = makeSpanData(attributes: attributes, events: events)

        // Create multiple isolated copies concurrently
        await withTaskGroup(of: SpanData.self) { group in
            for _ in 0 ..< 100 {
                group.addTask {
                    // Each task creates an isolated copy and accesses its data
                    let copy = original.isolatedCopy()

                    // Access all attributes to exercise the dictionary
                    for (key, value) in copy.attributes {
                        _ = key.count
                        _ = value.description
                    }

                    // Access events
                    for event in copy.events {
                        _ = event.name
                        for (key, value) in event.attributes {
                            _ = key.count
                            _ = value.description
                        }
                    }

                    return copy
                }
            }

            // Collect all results - if we get here without crashing, the test passes
            var copies: [SpanData] = []
            for await copy in group {
                copies.append(copy)
            }

            #expect(copies.count == 100)
        }
    }

    @Test
    func isolatedCopyWithRapidCreationAndDeallocation() async {
        // This test simulates the scenario that causes crashes:
        // rapid creation of SpanData copies followed by deallocation
        let attributes: [String: AttributeValue] = [
            "session.id": .string("test-session-123"),
            "screen.name": .string("HomeScreen"),
            "component": .string("ui")
        ]

        await withTaskGroup(of: Void.self) { group in
            for iteration in 0 ..< 50 {
                group.addTask {
                    // Create original span data
                    let original = self.makeSpanData(attributes: attributes)

                    // Create isolated copy (simulating what exporter does)
                    let isolated = original.isolatedCopy()

                    // Simulate processing delay
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 1000 ... 10000))

                    // Access the isolated copy's data (simulating SpanAdapter processing)
                    for (key, value) in isolated.attributes {
                        _ = "\(key): \(value.description)"
                    }

                    _ = iteration
                }
            }

            // Wait for all tasks to complete
            await group.waitForAll()
        }

        // If we reach here without crashing, the test passes
        #expect(true)
    }

    @Test
    func isolatedCopyMaintainsDataIntegrityUnderLoad() async {
        let expectedAttributes: [String: AttributeValue] = [
            "http.method": .string("GET"),
            "http.status_code": .int(200),
            "http.url": .string("https://example.com/api")
        ]
        let expectedEventName = "request.started"
        let expectedEventAttr = "timestamp"

        let events = [
            (name: expectedEventName, attributes: [expectedEventAttr: AttributeValue.string("2025-01-01")])
        ]

        let original = makeSpanData(attributes: expectedAttributes, events: events)

        // Run many concurrent copies and verify data integrity
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< 200 {
                group.addTask {
                    let copy = original.isolatedCopy()

                    // Verify all expected data is present and correct
                    guard copy.attributes["http.method"]?.description == "GET" else {
                        return false
                    }
                    guard copy.attributes["http.status_code"]?.description == "200" else {
                        return false
                    }
                    guard copy.attributes["http.url"]?.description == "https://example.com/api" else {
                        return false
                    }
                    guard copy.events.first?.name == expectedEventName else {
                        return false
                    }
                    guard copy.events.first?.attributes[expectedEventAttr]?.description == "2025-01-01" else {
                        return false
                    }

                    return true
                }
            }

            var allValid = true
            for await isValid in group {
                if !isValid {
                    allValid = false
                }
            }

            #expect(allValid, "All concurrent copies should maintain data integrity")
        }
    }
}


// MARK: - No-Op Span Exporter

/// A simple no-op exporter for testing purposes.
private class NoOpSpanExporter: SpanExporter {
    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout: TimeInterval?) {}
}
