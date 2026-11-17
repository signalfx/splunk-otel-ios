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

import XCTest

@testable import SplunkAgent

extension XCTestCase {

    // MARK: - Agent teardown

    /// Stops the agent when the current test ends.
    ///
    /// Call it right after the test builds or installs the agent. Teardown blocks run in reverse order,
    /// so call ``restoreOpenTelemetryGlobalsAtTeardown()`` before this method, and the agent stops
    /// before the globals are restored.
    ///
    /// - Parameter agent: The agent to stop with ``AgentTeardown/stop(_:)``.
    func stopAtTeardown(_ agent: SplunkRum) {
        addTeardownBlock { @MainActor in
            await AgentTeardown.stop(agent)
        }
    }

    /// Shuts down the pipeline of an event manager when the current test ends.
    ///
    /// Use it for an event manager that the test builds without installing the agent.
    ///
    /// - Parameter eventManager: The event manager to stop with ``AgentTeardown/stopPipeline(of:)``.
    func stopPipelineAtTeardown(_ eventManager: DefaultEventManager) {
        addTeardownBlock {
            AgentTeardown.stopPipeline(of: eventManager)
        }
    }

    /// Saves the global OpenTelemetry providers now and restores them when the current test ends.
    func restoreOpenTelemetryGlobalsAtTeardown() {
        let globals = OpenTelemetryGlobals()

        addTeardownBlock {
            globals.restore()
        }
    }
}
