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

// Navigation is the only module whose ObjC bridge needs agent-level types
// (NavigationModuleEventProcessor) for the processor callback chain.
// Other module conversions import only SplunkCommon + Splunk<Name>.
import SplunkAgent
internal import SplunkCommon
internal import SplunkNavigation

extension NavigationConfigurationObjC: ModuleConfigurationSwift {

    // MARK: - Swift variant

    var moduleConfiguration: any ModuleConfiguration {
        // The processor is routed through the agent facade
        // (ObjC -> NavigationModuleEventProcessor -> NavigationEventProcessor)
        // so it matches the Swift path's adapter chain.
        //
        // The config itself is built as SplunkNavigation.NavigationConfiguration
        // directly because SplunkAgent.NavigationConfiguration does not conform
        // to ModuleConfiguration (it holds non-Encodable processor references).
        // The two value-type properties (isEnabled, enableAutomatedTracking) are
        // forwarded verbatim. If the agent-level config gains derived fields or
        // validation in the future, replicate them here.
        let internalProcessor: (any NavigationEventProcessor)? =
            navigationEventProcessor
            .map { NavEventProcessorObjCToAgentAdapter(wrapping: $0) }
            .map { NavProcessorAgentToInternalAdapter(wrapping: $0) }

        return SplunkNavigation.NavigationConfiguration(
            isEnabled: isEnabled,
            enableAutomatedTracking: enableAutomatedTracking,
            navigationEventProcessor: internalProcessor
        )
    }
}
