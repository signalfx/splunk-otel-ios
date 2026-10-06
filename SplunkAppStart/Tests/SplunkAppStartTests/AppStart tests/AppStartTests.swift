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

import XCTest

@_spi(SplunkInternal) @testable import SplunkAppStart

final class AppStartTests: XCTestCase {

    // MARK: - Process and observation

    func testProcessStart() throws {
        let appStart = AppStart()
        let processStart = try XCTUnwrap(appStart.processStartTime())

        let duration = Date().timeIntervalSince(processStart)
        XCTAssertGreaterThan(duration, 0)
        XCTAssertLessThan(duration, 60)
    }
}

extension AppStartTests {

    // MARK: - Initial classification

    func testDelayedHybridHandoffUsesCapturedActivationAsEnd() throws {
        let processStart = Date(timeIntervalSinceReferenceDate: 2_000)
        let didBecomeActive = processStart.addingTimeInterval(0.287)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: nil,
                didBecomeActive: didBecomeActive
            )
        )

        let span = try XCTUnwrap(destination.storedAppStart)
        XCTAssertEqual(span.end, didBecomeActive)
        XCTAssertEqual(span.end.timeIntervalSince(span.start), 0.287, accuracy: 0.000001)
    }

    func testBackgroundResidenceIsExcludedFromWarmStart() throws {
        let processStart = Date(timeIntervalSinceReferenceDate: 3_000)
        let foreground = processStart.addingTimeInterval(3 * 60 * 60)
        let active = foreground.addingTimeInterval(0.4)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: foreground,
                didBecomeActive: active
            )
        )

        let span = try XCTUnwrap(destination.storedAppStart)
        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, foreground)
        XCTAssertEqual(span.end, active)
        XCTAssertEqual(span.end.timeIntervalSince(span.start), 0.4, accuracy: 0.000001)
    }

    func testBackgroundLaunchWaitsForFutureForeground() throws {
        let processStart = Date(timeIntervalSinceReferenceDate: 4_000)
        let foreground = processStart.addingTimeInterval(4 * 60 * 60)
        let active = foreground.addingTimeInterval(0.5)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: nil,
                didBecomeActive: nil
            )
        )

        XCTAssertNil(destination.storedAppStart)
        XCTAssertNil(appStart.suppressionReason)

        appStart.process(event: .willEnterForeground(foreground))
        appStart.process(event: .didBecomeActive(active))

        let span = try XCTUnwrap(destination.storedAppStart)
        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, foreground)
        XCTAssertEqual(span.end, active)
    }

    func testBackgroundLaunchWithoutForegroundSuppressesAtTermination() {
        let (appStart, destination) = configuredAppStart()
        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                didFinishLaunching: Date(),
                willEnterForeground: nil,
                didBecomeActive: nil
            )
        )

        appStart.process(event: .willTerminate)

        XCTAssertNil(destination.storedAppStart)
        XCTAssertEqual(appStart.suppressionReason, .backgroundWithoutForeground)
    }

    func testPrewarmTakesPrecedenceOverForegroundSnapshot() throws {
        let processStart = Date(timeIntervalSinceReferenceDate: 5_000)
        let foreground = processStart.addingTimeInterval(120)
        let active = foreground.addingTimeInterval(0.3)
        let (appStart, destination) = configuredAppStart(processStart: processStart)
        appStart.prewarmDetected = true

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: foreground,
                didBecomeActive: active
            )
        )

        let span = try XCTUnwrap(destination.storedAppStart)
        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, foreground)
    }

    func testPrewarmWithoutForegroundBoundaryIsSuppressed() {
        let processStart = Date(timeIntervalSinceReferenceDate: 5_500)
        let (appStart, destination) = configuredAppStart(processStart: processStart)
        appStart.prewarmDetected = true

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .unknown,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: nil,
                didBecomeActive: processStart.addingTimeInterval(1)
            )
        )

        XCTAssertNil(destination.storedAppStart)
        XCTAssertEqual(appStart.suppressionReason, .missingForegroundBoundary)
    }

    func testIncompleteUnknownHandoffCannotBecomeLongColdStart() {
        let processStart = Date(timeIntervalSinceReferenceDate: 5_750)
        let foreground = processStart.addingTimeInterval(4 * 60 * 60)
        let active = foreground.addingTimeInterval(0.4)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .unknown,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: nil,
                didBecomeActive: nil
            )
        )
        appStart.process(event: .willEnterForeground(foreground))
        appStart.process(event: .didBecomeActive(active))

        XCTAssertNil(destination.storedAppStart)
        XCTAssertEqual(appStart.suppressionReason, .unknownLaunchOrigin)
    }
}

extension AppStartTests {

    // MARK: - Suppression and validation

    func testAmbiguousLegacyForegroundHandoffIsSuppressed() {
        let processStart = Date(timeIntervalSinceReferenceDate: 6_000)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            didBecomeActive: processStart.addingTimeInterval(1),
            didFinishLaunching: processStart.addingTimeInterval(0.2),
            willEnterForeground: nil
        )

        XCTAssertNil(destination.storedAppStart)
        XCTAssertEqual(appStart.suppressionReason, .unknownLaunchOrigin)
    }

    func testNativeForegroundBoundaryWithoutLaunchEvidenceIsNotClassified() {
        let processStart = Date(timeIntervalSinceReferenceDate: 6_500)
        let foreground = processStart.addingTimeInterval(3 * 60 * 60)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.process(event: .willEnterForeground(foreground))
        appStart.process(event: .didBecomeActive(foreground.addingTimeInterval(0.2)))

        XCTAssertNil(destination.storedAppStart)
        XCTAssertNil(appStart.suppressionReason)

        appStart.process(event: .didEnterBackground)

        XCTAssertEqual(appStart.suppressionReason, .unknownLaunchOrigin)
    }

    func testLegacyForegroundBoundaryWithoutProvenanceIsSuppressed() {
        let processStart = Date(timeIntervalSinceReferenceDate: 7_000)
        let foreground = processStart.addingTimeInterval(60)
        let active = foreground.addingTimeInterval(0.2)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            didBecomeActive: active,
            didFinishLaunching: processStart.addingTimeInterval(0.1),
            willEnterForeground: foreground
        )

        XCTAssertNil(destination.storedAppStart)
        XCTAssertEqual(appStart.suppressionReason, .unknownLaunchOrigin)
    }

    func testReversedTimestampsAreSuppressed() {
        let processStart = Date(timeIntervalSinceReferenceDate: 8_000)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: processStart.addingTimeInterval(2),
                willEnterForeground: nil,
                didBecomeActive: processStart.addingTimeInterval(1)
            )
        )

        XCTAssertNil(destination.storedAppStart)
        XCTAssertEqual(appStart.suppressionReason, .invalidTimestampOrder)
    }

    func testForegroundBeforeLaunchTimestampIsSuppressed() {
        let processStart = Date(timeIntervalSinceReferenceDate: 8_500)
        let foreground = processStart.addingTimeInterval(1)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                didFinishLaunching: foreground.addingTimeInterval(1),
                willEnterForeground: foreground,
                didBecomeActive: foreground.addingTimeInterval(2)
            )
        )

        XCTAssertNil(destination.storedAppStart)
        XCTAssertEqual(appStart.suppressionReason, .invalidTimestampOrder)
    }

    func testNonFiniteTimestampIsSuppressed() {
        let processStart = Date(timeIntervalSinceReferenceDate: 9_000)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: nil,
                willEnterForeground: nil,
                didBecomeActive: Date(timeIntervalSinceReferenceDate: .infinity)
            )
        )

        XCTAssertNil(destination.storedAppStart)
        XCTAssertEqual(appStart.suppressionReason, .invalidTimestampOrder)
    }

    func testInitialMeasurementIsEmittedExactlyOnce() {
        let processStart = Date(timeIntervalSinceReferenceDate: 10_000)
        let active = processStart.addingTimeInterval(1)
        let (appStart, destination) = configuredAppStart(processStart: processStart)
        let snapshot = AppStartLifecycleSnapshot(
            launchOrigin: .foreground,
            didFinishLaunching: processStart.addingTimeInterval(0.1),
            willEnterForeground: nil,
            didBecomeActive: active
        )

        appStart.track(initialLifecycle: snapshot)
        appStart.track(initialLifecycle: snapshot)
        appStart.process(event: .didBecomeActive(active.addingTimeInterval(1)))

        XCTAssertEqual(destination.storedAppStarts.count, 1)
    }

    func testConflictingNativeAndHybridOriginsAreSuppressed() {
        let processStart = Date(timeIntervalSinceReferenceDate: 10_500)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.process(
            event: .didFinishLaunching(
                processStart.addingTimeInterval(0.05),
                .background
            )
        )
        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: nil,
                didBecomeActive: processStart.addingTimeInterval(1)
            )
        )

        XCTAssertNil(destination.storedAppStart)
        XCTAssertEqual(appStart.suppressionReason, .conflictingLaunchOrigin)
    }
}

extension AppStartTests {

    // MARK: - Helpers

    func configuredAppStart(
        processStart: Date = Date(timeIntervalSinceReferenceDate: 100)
    ) -> (AppStart, DebugDestination) {
        let destination = DebugDestination()
        let appStart = AppStart()
        appStart.processStartTimestamp = processStart
        appStart.destination = destination

        return (appStart, destination)
    }
}
