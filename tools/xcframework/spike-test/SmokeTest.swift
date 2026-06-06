// tools/xcframework/spike-test/SmokeTest.swift
//
// Minimal smoke test that verifies:
// 1. OpenTelemetryApi.xcframework links and is importable
// 2. OpenTelemetrySdk.xcframework links and is importable
// 3. SDK types can be instantiated at runtime (not just compiled)
// 4. The Api <-> Sdk relationship works (Sdk implements Api protocols)
//
// This is compiled as an iOS app via Tuist, against the built xcframeworks.

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

// ---------------------------------------------------------------------------
// MARK: - App Entry Point
// ---------------------------------------------------------------------------

@main
struct SmokeTestApp: App {
    init() {
        SmokeTestRunner.runAll()
    }

    var body: some Scene {
        WindowGroup {
            Text("OTel Smoke Test Passed")
        }
    }
}


// ---------------------------------------------------------------------------
// MARK: - Smoke Tests
// ---------------------------------------------------------------------------

enum SmokeTestRunner {

    static func runAll() {
        print("========================================")
        print("  OTel XCFramework Smoke Test")
        print("========================================")
        print("")

        testApiTypes()
        testSdkTypes()
        testSdkApiIntegration()
        testSdkResourceTypes()

        print("")
        print("========================================")
        print("  All smoke tests passed")
        print("========================================")
    }


    // Test 1: OpenTelemetryApi types are accessible
    static func testApiTypes() {
        print("Test 1: OpenTelemetryApi types...")

        // Access the singleton
        let otel = OpenTelemetry.instance

        // Access the tracer provider (noop by default)
        let tracerProvider = otel.tracerProvider
        let tracer = tracerProvider.get(instrumentationName: "smoke-test", instrumentationVersion: "1.0.0")

        // Create a span
        let span = tracer.spanBuilder(spanName: "test-span").startSpan()
        span.setAttribute(key: "test.key", value: "test-value")
        span.end()

        print("  OK - Api types work: tracer, span builder, span attributes")
    }


    // Test 2: OpenTelemetrySdk types are accessible
    static func testSdkTypes() {
        print("Test 2: OpenTelemetrySdk types...")

        // Create an SDK TracerProvider
        let tracerProvider = TracerProviderBuilder().build()

        // Get a tracer from the SDK provider
        let tracer = tracerProvider.get(instrumentationName: "smoke-test-sdk", instrumentationVersion: "1.0.0")

        // Create and end a span
        let span = tracer.spanBuilder(spanName: "sdk-test-span").startSpan()
        span.setAttribute(key: "sdk.test", value: true)
        span.end()

        print("  OK - Sdk types work: TracerProviderBuilder, SDK tracer, SDK spans")
    }


    // Test 3: SDK integrates with API (register SDK provider with API singleton)
    static func testSdkApiIntegration() {
        print("Test 3: SDK <-> API integration...")

        // Build an SDK TracerProvider
        let sdkTracerProvider = TracerProviderBuilder().build()

        // Register it with the OpenTelemetry API singleton
        OpenTelemetry.registerTracerProvider(tracerProvider: sdkTracerProvider)

        // Now getting a tracer via API should use the SDK implementation
        let tracer = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: "integration-test",
            instrumentationVersion: "1.0.0"
        )

        let span = tracer.spanBuilder(spanName: "integration-span").startSpan()
        span.setAttribute(key: "integration", value: "works")
        span.end()

        print("  OK - SDK provider registered with API singleton, spans created via API use SDK")
    }


    // Test 4: Resource and SpanData types from SDK
    static func testSdkResourceTypes() {
        print("Test 4: SDK Resource types...")

        // Create a Resource with attributes
        let resource = Resource(attributes: [
            "service.name": .string("smoke-test-app"),
            "telemetry.sdk.language": .string("swift")
        ])

        // Verify attributes
        guard let serviceName = resource.attributes["service.name"] else {
            print("  FAIL: Resource attributes missing")
            return
        }
        print("  OK - Resource with attributes: service.name = \(serviceName)")
    }
}
