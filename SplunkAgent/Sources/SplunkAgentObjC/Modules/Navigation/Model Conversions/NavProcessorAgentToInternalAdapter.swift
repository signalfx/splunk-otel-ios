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

import SplunkAgent
internal import SplunkNavigation

/// Adapts a ``NavigationModuleEventProcessor`` (agent facade) to the
/// internal ``NavigationEventProcessor`` used by the navigation engine.
///
/// Duplicates ``NavigationModuleEventProcessorAdapter`` in `SplunkAgent`,
/// which is `internal` and inaccessible from this target. We intentionally
/// duplicate rather than widen access (e.g. `package`) to preserve
/// compile-time target isolation.
final class NavProcessorAgentToInternalAdapter: NavigationEventProcessor, @unchecked Sendable {

    // MARK: - Private

    private let agentProcessor: any NavigationModuleEventProcessor


    // MARK: - Initialization

    init(wrapping agentProcessor: any NavigationModuleEventProcessor) {
        self.agentProcessor = agentProcessor
    }


    // MARK: - NavigationEventProcessor

    func onViewController(typeName: String, controllerIdentity: String) -> NavigationEvent? {

        guard
            let agentEvent = agentProcessor.onViewController(
                typeName: typeName,
                controllerIdentity: controllerIdentity
            )
        else {
            return nil
        }

        return NavigationEvent(
            name: agentEvent.name,
            attributes: agentEvent.attributes
        )
    }
}
