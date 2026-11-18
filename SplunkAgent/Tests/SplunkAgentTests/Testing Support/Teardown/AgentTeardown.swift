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

import CiscoLogger
import SplunkAppStart
import SplunkNetwork
import SplunkNetworkMonitor

@testable import SplunkAgent
@testable import SplunkAppState
@testable import SplunkSlowFrameDetector

/// Stops agents that tests build, so that they cannot affect later tests.
///
/// An installed agent is never freed: its modules manager and its modules keep it alive. So after a
/// test ends, the agent still observes lifecycle notifications on `NotificationCenter.default` and
/// still emits spans through the global tracer provider. These helpers stop that work without freeing
/// the agent. A freed agent is unsafe, because its session and its event manager keep `unowned`
/// references to it.
///
/// The helpers have no XCTest dependency, so XCTest cases and Swift Testing suites can both use them.
/// XCTest cases normally use the `XCTestCase` helpers in `XCTestCase+AgentTeardown.swift`.
enum AgentTeardown {

    // MARK: - Agents

    /// Stops the modules, the remote configuration updates and the logging of an agent.
    ///
    /// The agent stays allocated but no longer reacts to notifications. Modules that have no stop API
    /// (for example Navigation, Interactions, WebView, Crash Reports and Session Replay) keep running.
    /// Lifecycle observers of `DefaultSession` and `AppStateManager` also stay registered, as the
    /// agent does not keep their tokens.
    ///
    /// The pipeline is left as it is. Shutting it down drains the buffered spans of the test through
    /// the agent's span interceptor while the agent is still alive, which can release held session
    /// starts and fulfill the test's expectations again after the test ends. With the modules stopped
    /// and the global providers restored, nothing feeds the pipeline any more.
    ///
    /// This method does not restore the global OpenTelemetry providers; use ``OpenTelemetryGlobals``
    /// for that.
    ///
    /// - Parameter agent: The agent to stop. Calling this method again for the same agent is safe.
    @MainActor
    static func stop(_ agent: SplunkRum) async {
        await stopModules(of: agent)

        if let configurationHandler = agent.agentConfigurationHandler as? ConfigurationHandler {
            configurationHandler.cancellables.removeAll()
            configurationHandler.invalidateReloadSessionTimer()
        }

        (agent.currentSession as? DefaultSession)?.refreshJob?.suspend()

        // Each agent adds a log processor to the shared log pool, and every processor prints every line
        _ = agent.logProcessor.verbosity(.silent)
    }


    // MARK: - Private methods

    @MainActor
    private static func stopModules(of agent: SplunkRum) async {
        let modules = (agent.modulesManager as? DefaultModulesManager)?.modules ?? []

        for module in modules {
            switch module {
            case let appState as AppStateModule:
                appState.stopDetection()

            case let appStart as SplunkAppStart.AppStart:
                appStart.stopDetection()

            case let network as NetworkInstrumentation:
                network.uninstall()

            case let networkMonitor as NetworkMonitor:
                networkMonitor.stopDetection()

            case let slowFrameDetector as SplunkSlowFrameDetector.SlowFrameDetector:
                await slowFrameDetector.stop()

            default:
                break
            }
        }
    }
}
