//
// SmokeTestApp.swift
// XCFramework Smoke Test
//
// Minimal app that verifies all SplunkAgent xcframeworks can be linked
// and basic runtime initialization works.
//
// This is NOT a unit test -- it's a build-time verification that all
// modules resolve and link correctly when consumed as xcframeworks.

import OpenTelemetryApi
import OpenTelemetrySdk
import SplunkAgent
import SplunkAgentObjC
import SwiftUI

#if canImport(CrashReporter)
    import CrashReporter
#endif


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

        // Check 3: Public SplunkAgent module configuration wrappers are accessible
        let moduleConfigurations: [Any] = [
            NavigationConfiguration(isEnabled: true, enableAutomatedTracking: false),
            NetworkInstrumentationConfiguration(isEnabled: true, ignoreURLs: nil),
            NetworkMonitorConfiguration(isEnabled: true),
            SlowFrameDetectorConfiguration(isEnabled: true),
            CrashReportsConfiguration(isEnabled: true),
            SessionReplayConfiguration(enabled: false, samplingRate: 0.0),
            InteractionsConfiguration(isEnabled: true),
            WebViewInstrumentationConfiguration(),
            AppStartConfiguration(),
            AppStateConfiguration(),
            CustomTrackingConfiguration()
        ]
        if moduleConfigurations.count == 11 {
            results.append("PASS: SplunkAgent module configurations accessible")
        }
        else {
            results.append("FAIL: SplunkAgent module configuration count mismatch")
        }

        // Check 4: SplunkAgentObjC public configuration types are accessible
        let objcConfiguration = NavigationConfigurationObjC(isEnabled: true, enableAutomatedTracking: false)
        if objcConfiguration.isEnabled {
            results.append("PASS: SplunkAgentObjC types accessible")
        }
        else {
            results.append("FAIL: SplunkAgentObjC configuration mismatch")
        }

        // Check 5: OpenTelemetry API types are accessible
        let _ = SpanKind.client
        results.append("PASS: OpenTelemetryApi types accessible (SpanKind)")

        // Check 6: OpenTelemetry SDK types are accessible
        let _ = SpanLimits()
        results.append("PASS: OpenTelemetrySdk types accessible (SpanLimits)")

        // Check 7: PLCrashReporter is accessible only on supported platforms
        #if canImport(CrashReporter)
            let _ = PLCrashReporterConfig.defaultConfiguration()
            results.append("PASS: CrashReporter types accessible (PLCrashReporterConfig)")
        #else
            results.append("PASS: CrashReporter unavailable on this platform")
        #endif

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
