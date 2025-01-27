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

class DefaultModulesManager: AgentModulesManager {

    // MARK: - Private

    private var modulesPool: AgentModulesPool.Type
    private var modulesDataConsumer: ((any ModuleEventMetadata, any ModuleEventData) -> Void)?


    // MARK: - Public

    private(set) var modules: [any Module] = []


    // MARK: - Initialization

    required init(rawConfiguration: Data?, moduleConfigurations: [Any]?,
                  for pool: AgentModulesPool.Type = DefaultModulesPool.self) {

        modulesPool = pool

        // Initializes all known modules
        let agentModules: [any Module] = modulesPool.default.map { moduleType in
            initializeModule(type: moduleType)
        }


        // All local module configurations
        let configurations = moduleConfigurations?.compactMap { moduleConfiguration in
            moduleConfiguration as? ModuleConfiguration
        } ?? []

        // Creates remote module configurations from raw data
        let remoteConfigurations: [any RemoteModuleConfiguration] = modulesPool.default.compactMap { moduleType in
            initializeRemoteConfiguration(
                from: rawConfiguration,
                forModule: moduleType
            )
        }


        // Perform modules connection
        connect(
            modules: agentModules,
            with: configurations,
            remoteConfigurations: remoteConfigurations
        )
    }

    /// Helper method for generic module initialization.
    private func initializeModule<T: Module>(type: T.Type) -> T {
        return T()
    }

    /// Helper method for generic initialization of remote configuration.
    private func initializeRemoteConfiguration<T: Module>(from data: Data?, forModule type: T.Type) -> T.RemoteConfiguration? {
        guard let data else {
            return nil
        }

        return T.RemoteConfiguration(from: data)
    }


    // MARK: - Business Logic

    func connect(modules: [any Module], with configurations: [any ModuleConfiguration],
                 remoteConfigurations: [any RemoteModuleConfiguration]) {
        // Connect all modules with corresponding configurations (if exists)
        for module in modules {
            // Get corresponding configuration
            let configuration = configurations.filter { configuration in
                let configurationType = type(of: configuration)

                return type(of: module).acceptsConfiguration(type: configurationType)
            }.first

            // Get corresponding remote configuration
            let remoteConfiguration = remoteConfigurations.filter { remoteConfiguration in
                let configurationType = type(of: remoteConfiguration)

                return type(of: module).acceptsRemoteConfiguration(type: configurationType)
            }.first

            // Try to connect module
            connect(
                module: module,
                with: configuration,
                remoteConfiguration: remoteConfiguration
            )
        }
    }

    private func connect(module: any Module, with configuration: (any ModuleConfiguration)?,
                         remoteConfiguration: (any RemoteModuleConfiguration)?) {
        // We will not add remotely disabled modules
        guard remoteConfiguration?.enabled ?? true else {
            return
        }

        // Each module can be connected only once to same agent instance
        let isConnected = modules.contains { moduleItem in
            type(of: module.self) == type(of: moduleItem.self)
        }

        guard !isConnected else {
            return
        }


        // Add module instance into managed modules
        modules.append(module)

        // Install and configure module for this agent
        module.install(with: configuration, remoteConfiguration: remoteConfiguration)
        module.onPublish(data: onModulePublish)
    }


    // MARK: - Data forwarding

    // Forwards data from modules to consumer class (some DataProcessor)
    private func onModulePublish(metadata: any ModuleEventMetadata, data: any ModuleEventData) {
        // Gets data from modules and forwards then into assigned data processor
        modulesDataConsumer?(metadata, data)
    }


    // MARK: - Data publication

    // Observe published data from all modules
    func onModulePublish(data block: @escaping (any ModuleEventMetadata, any ModuleEventData) -> Void) {
        modulesDataConsumer = block
    }

    // Asks the module manager to delete specific data
    // that was previously published by some of the modules
    func deleteModuleData(for metadata: any ModuleEventMetadata) {
        // Finds a module that understands the format of this metadata
        let module: (any Module)? = modules.filter { module in
            let moduleType = type(of: module)
            let metadataType = type(of: metadata)

            return moduleType.acceptsMetadata(type: metadataType)
        }.first

        // Forward request into corresponding module
        if let module {
            module.deleteData(for: metadata)
        }
    }
}
