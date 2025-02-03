//
/*
Copyright 2024 Splunk Inc.

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
@_implementationOnly import SplunkSharedProtocols

/// Defines the basic properties and behavior of the modules manager.
///
/// The modules manager holds and manages instances of modules for the current agent instances.
/// It also serves as a unifying point for taking data from modules and publishing it
/// in a unified way to downstream components.
protocol AgentModulesManager {

    // MARK: - Public

    /// Array of all module instances managed by this agent instance.
    var modules: [any Module] { get }


    // MARK: - Initialization

    /// Initializes manager with a raw variant of remote configuration.
    ///
    /// - Parameters:
    ///   - rawConfiguration: A `Data` with raw remote configuration in JSON format.
    ///   - moduleConfigurations: List of user configurations for managed modules.
    ///   - pool: The pool type of available modules.
    init(rawConfiguration: Data?, moduleConfigurations: [Any]?, for pool: AgentModulesPool.Type)


    // MARK: - Business Logic

    /// Connects and initializes individual modules and performs their initial configuration.
    ///
    /// - Parameters:
    ///   - modules: List of connected modules.
    ///   - configurations: A set of relevant module configurations.
    ///   - remoteConfigurations: A set of relevant remote configurations.
    func connect(modules: [any Module], with configurations: [any ModuleConfiguration],
                 remoteConfigurations: [any RemoteModuleConfiguration])

    /// Returns the module instance managed by this manager.
    ///
    /// - Parameter type: The requested module type.
    ///
    /// - Returns: Module instance or `nil` if this instance does not manage that module.
    func module<T: Module>(ofType type: T.Type) -> T?


    // MARK: - Data publication

    /// Observe published data from all modules.
    ///
    /// The published data isn't deleted by default until we have
    /// an exact request to delete it via the `deleteModuleData(for:)` method.
    ///
    /// - Parameter block: A closure for taking over published data.
    func onModulePublish(data block: @escaping (any ModuleEventMetadata, any ModuleEventData) -> Void)

    /// Asks the module manager to delete specific data that it has previously published.
    ///
    /// - Parameter metadata: A struct with essential data identification.
    func deleteModuleData(for metadata: any ModuleEventMetadata)
}


extension AgentModulesManager {

    // MARK: - Business Logic

    func module<T: Module>(ofType type: T.Type) -> T? {
        let matches = modules.filter { module in
            (module as? T) != nil
        } as? [T]

        return matches?.first
    }
}
