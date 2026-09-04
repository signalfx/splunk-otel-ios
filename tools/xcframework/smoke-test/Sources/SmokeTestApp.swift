//
// SmokeTestApp.swift
// XCFramework Smoke Test
//
// Minimal app that verifies all SplunkAgent xcframeworks can be linked
// and basic runtime initialization works.
//
// This is NOT a unit test -- it's a build-time verification that all
// modules resolve and link correctly when consumed as xcframeworks.

// Each import below proves the corresponding xcframework is found by the
// linker and the Swift module interface resolves correctly.

import CiscoDiskStorage
import CiscoEncryption
import CiscoInstanceManager
import CiscoInteractions
import CiscoLogger
import CiscoRuntimeCache
import CiscoSessionReplay
import CiscoSwizzling
import OpenTelemetryApi
import OpenTelemetrySdk
import SplunkAgent
import SplunkCrashReporter
import SwiftUI


// ---------------------------------------------------------------------------
// MARK: - Smoke Test Runner
// ---------------------------------------------------------------------------

/// Runs basic verification checks at app launch.
enum SmokeTestRunner {

    /// Runs all smoke test checks and prints results.
    static func run() -> [String] {
        var results: [String] = []

        // Check 1: SplunkRum version is accessible
        let version = SplunkRum.version
        if !version.isEmpty {
            results.append("PASS: SplunkRum.version = \(version)")
        }
        else {
            results.append("FAIL: SplunkRum.version is empty")
        }

        // Check 2: AgentConfiguration can be constructed
        let endpoint = EndpointConfiguration(realm: "us0", rumAccessToken: "smoke-test-token")
        let config = AgentConfiguration(
            endpoint: endpoint,
            appName: "SmokeTest",
            deploymentEnvironment: "test"
        )
        if config.appName == "SmokeTest" {
            results.append("PASS: AgentConfiguration constructed")
        }
        else {
            results.append("FAIL: AgentConfiguration.appName mismatch")
        }

        // Check 3: OpenTelemetry API types are accessible
        let _ = SpanKind.client
        results.append("PASS: OpenTelemetryApi types accessible (SpanKind)")

        // Check 4: OpenTelemetry SDK types are accessible
        let _ = SpanLimits()
        results.append("PASS: OpenTelemetrySdk types accessible (SpanLimits)")

        // Check 5: PLCrashReporter type is accessible
        let _ = SPLKPLCrashReporterConfig.defaultConfiguration()
        results.append("PASS: SplunkCrashReporter types accessible (SPLKPLCrashReporterConfig)")

        return results
    }
}


// ---------------------------------------------------------------------------
// MARK: - SwiftUI App
// ---------------------------------------------------------------------------

@main
struct SmokeTestApp: App {

    init() {
        print("=== XCFramework Smoke Test ===")
        let results = SmokeTestRunner.run()
        for result in results {
            print("  \(result)")
        }
        let passed = results.filter { $0.hasPrefix("PASS") }.count
        let total = results.count
        print("=== Results: \(passed)/\(total) passed ===")

        if passed == total {
            print("✓ All smoke tests passed")
        }
        else {
            print("✗ Some smoke tests failed")
        }
    }

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                Text("XCFramework Smoke Test")
                    .font(.headline)
                Text("SplunkRum v\(SplunkRum.version)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}
