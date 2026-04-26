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
/// This adapter mirrors ``NavigationModuleEventProcessorAdapter`` in
/// `SplunkAgent` but lives in `SplunkAgentObjC` so the ObjC bridging
/// layer can compose it with ``NavEventProcessorObjCToAgentAdapter``,
/// routing the full chain through the agent facade:
///
///     ObjC → agent-level → internal
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
