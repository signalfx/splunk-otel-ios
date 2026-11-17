//
/*
Copyright 2026 Splunk Inc.

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

import OpenTelemetryApi
import SplunkCommon
import XCTest

@testable import SplunkAgent
@testable import SplunkAppState
@testable import SplunkOpenTelemetry

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#endif

final class AgentTeardownTests: XCTestCase {

    // MARK: - Installed agent

    #if os(iOS) || os(tvOS) || os(visionOS)

        @MainActor
        func testStopEndsLifecycleEventsAndPipelineOfInstalledAgent() async throws {
            addTeardownBlock {
                SplunkRum.resetSharedInstance()
            }
            restoreOpenTelemetryGlobalsAtTeardown()

            let configuration = try ConfigurationTestBuilder.buildDefault()
            let agent = try SplunkRum.install(with: configuration)
            stopAtTeardown(agent)

            let modules = try XCTUnwrap((agent.modulesManager as? DefaultModulesManager)?.modules)
            let appState = try XCTUnwrap(modules.compactMap { $0 as? AppStateModule }.first)
            let destination = RecordingAppStateDestination()
            appState.destination = destination

            let eventManager = try XCTUnwrap(agent.eventManager as? DefaultEventManager)
            let tracerProvider = eventManager.concreteTraceProcessor.tracerProvider

            // Before the stop, the agent reacts to lifecycle notifications
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            XCTAssertEqual(destination.states, [.active])
            XCTAssertTrue(isRecording(tracerProvider))

            await AgentTeardown.stop(agent)

            // After the stop, it does not
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            XCTAssertEqual(destination.states, [.active])
            XCTAssertTrue(appState.notificationObservers.isEmpty)
            XCTAssertFalse(isRecording(tracerProvider))
        }

    #endif


    // MARK: - Test-built agent

    @MainActor
    func testStopCancelsRemoteConfigurationUpdates() async throws {
        let configuration = try ConfigurationTestBuilder.buildDefault()
        let agent = try AgentTestBuilder.build(with: configuration)
        let configurationHandler = try XCTUnwrap(agent.agentConfigurationHandler as? ConfigurationHandler)

        // The handler fetches a remote configuration on each session reset
        XCTAssertFalse(configurationHandler.cancellables.isEmpty)

        await AgentTeardown.stop(agent)

        XCTAssertTrue(configurationHandler.cancellables.isEmpty)
        XCTAssertNil(configurationHandler.reloadSessionTimer)
    }


    // MARK: - Pipeline without install

    func testStopPipelineShutsDownTracerProvider() throws {
        restoreOpenTelemetryGlobalsAtTeardown()

        let configuration = try ConfigurationTestBuilder.buildDefault()
        let agent = try AgentTestBuilder.build(with: configuration)
        let eventManager = try DefaultEventManager(with: configuration, agent: agent)
        agent.eventManager = eventManager

        let tracerProvider = eventManager.concreteTraceProcessor.tracerProvider
        XCTAssertTrue(isRecording(tracerProvider))

        AgentTeardown.stopPipeline(of: eventManager)

        XCTAssertFalse(isRecording(tracerProvider))
    }


    // MARK: - OpenTelemetry globals

    func testRestoreRegistersSavedProviders() throws {
        let globals = OpenTelemetryGlobals()
        defer {
            globals.restore()
        }

        let configuration = try ConfigurationTestBuilder.buildDefault()
        let agent = try AgentTestBuilder.build(with: configuration)
        let eventManager = try DefaultEventManager(with: configuration, agent: agent)
        agent.eventManager = eventManager
        defer {
            AgentTeardown.stopPipeline(of: eventManager)
        }

        // Building a pipeline replaces both global providers
        XCTAssertFalse(isSame(OpenTelemetry.instance.tracerProvider, globals.tracerProvider))
        XCTAssertFalse(isSame(OpenTelemetry.instance.loggerProvider, globals.loggerProvider))

        globals.restore()

        XCTAssertTrue(isSame(OpenTelemetry.instance.tracerProvider, globals.tracerProvider))
        XCTAssertTrue(isSame(OpenTelemetry.instance.loggerProvider, globals.loggerProvider))
    }


    // MARK: - Private methods

    /// Returns whether a span started on the provider records, which a shut-down provider does not do.
    private func isRecording(_ tracerProvider: any TracerProvider) -> Bool {
        let span =
            tracerProvider
            .get(instrumentationName: "AgentTeardownTests", instrumentationVersion: nil)
            .spanBuilder(spanName: "teardown-probe")
            .startSpan()
        defer {
            span.end()
        }

        return span.isRecording
    }

    private func isSame(_ lhs: Any, _ rhs: Any) -> Bool {
        (lhs as AnyObject) === (rhs as AnyObject)
    }
}


// MARK: - Test doubles

/// Records the app states that the AppState module sends.
private final class RecordingAppStateDestination: AppStateDestination {

    // MARK: - Recorded data

    private(set) var states: [AppStateType] = []


    // MARK: - AppStateDestination

    func send(appState: AppStateType, time _: Date, sharedState _: AgentSharedState?) {
        states.append(appState)
    }
}
