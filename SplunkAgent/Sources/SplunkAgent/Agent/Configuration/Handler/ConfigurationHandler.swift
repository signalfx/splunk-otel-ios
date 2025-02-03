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

import Combine
import Foundation
@_implementationOnly import SplunkLogger

final class ConfigurationHandler: AgentConfigurationHandler, ObservableObject {

    // MARK: - Internal properties

    private(set) var configuration: AgentConfiguration

    let apiClient: AgentAPIClient
    let storage: KeyValueStorage

    var reloadSessionTimer: Timer?
    var cancellables = [AnyCancellable]()

    let internalLogger = InternalLogger(configuration: .agent(category: "ConfigurationHandler"))


    // MARK: - Public properties

    var configurationData: Data? {
        didSet {
            setupConfiguration(data: configurationData)
        }
    }


    // MARK: - Initialization

    init(for configuration: AgentConfiguration, apiClient: AgentAPIClient, storage: KeyValueStorage = UserDefaultsStorage()) {
        self.configuration = configuration
        self.apiClient = apiClient
        self.storage = storage

        setupObservers()

        configurationData = loadStoredConfiguration()
        setupConfiguration(data: configurationData)
        loadRemoteConfiguration()
    }


    // MARK: - Deinitialization

    deinit {
        invalidateReloadSessionTimer()
    }


    // MARK: - Private functions

    private func setupObservers() {
        NotificationCenter
            .default
            .publisher(for: DefaultSession.sessionWillResetNotification)
            .sink { [weak self] _ in
                self?.internalLogger.log(level: .info) {
                    "Session will reset, fetching new configuration."
                }

                self?.loadRemoteConfiguration()
            }
            .store(in: &cancellables)
    }

    private func setupConfiguration(data: Data?) {
        guard let data, !data.isEmpty else {
            internalLogger.log(level: .info) {
                "Missing configuration data, aborting setting up configuration."
            }

            return
        }

        do {
            let remoteConfiguration = try RemoteConfiguration.decode(data)
            configuration.mergeRemote(remoteConfiguration)
        } catch {
            internalLogger.log(level: .info) {
                "Failed to decode remote configuration data with an error: \(error)."
            }
        }
    }
}
