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

import Foundation
import SplunkCommon

public struct NavigationData: ModuleEventData {}

public struct NavigationMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}

/// Defines Navigation conformance to `Module` protocol
extension Navigation: Module {

    // MARK: - Module types

    public typealias Configuration = NavigationConfiguration
    public typealias RemoteConfiguration = NavigationRemoteConfiguration

    public typealias EventMetadata = NavigationMetadata
    public typealias EventData = NavigationData


    // MARK: - Module methods

    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration _: (any RemoteModuleConfiguration)?) {
        let configuration = configuration as? Configuration

        // Setup initial configuration and start detection once the model is fully configured.
        setup(with: configuration)
    }

    public func deleteData(for _: any ModuleEventMetadata) {}

    public func onPublish(data _: @escaping (NavigationMetadata, NavigationData) -> Void) {}


    // MARK: - Private methods

    private func setup(with configuration: Configuration?) {
        let isEnabled = configuration?.isEnabled ?? true
        let processor = configuration?.navigationEventProcessor

        // Update preferences
        if let configuration {
            preferences.enableAutomatedTracking = configuration.enableAutomatedTracking
        }

        // Update module mode and navigation event processor, then start detection.
        //
        // This necessarily has nested Tasks (in startDetection()) but the nesting
        // is transient: this outer Task exits immediately after startDetection()
        // returns, because startDetection() just enqueues two inner Tasks and
        // returns synchronously. The inner Tasks are long-lived detection loops
        // but they are siblings, not children, of this outer Task. The nesting is
        // an artifact of sequencing, not of structure.
        //
        // The processor must be set on the model before detection starts; given
        // that the module framework constructs Navigation before config is available
        // and that NavigationModel is deliberately an actor, this is the best
        // sequencing approach we have found.
        // Mirror enabled state synchronously so manual track() can check it
        // without an actor hop.
        runtimeStateStore.setModuleEnabled(isEnabled)

        Task {
            await model.update(moduleEnabled: isEnabled)

            if let processor {
                await model.update(navigationEventProcessor: processor)
            }

            if isEnabled {
                startDetection()
            }
        }
    }
}
