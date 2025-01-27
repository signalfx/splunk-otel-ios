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

extension ConfigurationHandler {

    // MARK: - Remote configuration fetching

    func loadRemoteConfiguration() {
        invalidateReloadSessionTimer()

        Task {
            do {
                let receivedData = try await fetchRemoteConfiguration()
                self.configurationData = receivedData
                storeConfiguration(receivedData)

                self.internalLogger.log(level: .info) {
                    "Remote configuration was successfully fetched and stored."
                }
            } catch let error as APIClientError {
                handleAPIClientError(error)

            } catch let error as ConfigurationHandlerError {
                handleConfigurationHandlerError(error)

            } catch {
                handleError(error)
            }
        }
    }


    // MARK: - Timer setup

    func setupReloadTimer(in ms: TimeInterval) {
        guard reloadSessionTimer == nil else {
            return
        }

        reloadSessionTimer = Timer.scheduledTimer(withTimeInterval: ms, repeats: false) { [weak self] _ in
            self?.loadRemoteConfiguration()
        }
        reloadSessionTimer?.tolerance = 5
    }


    // MARK: - Timer invalidation

    func invalidateReloadSessionTimer() {
        reloadSessionTimer?.invalidate()
        reloadSessionTimer = nil
    }


    // MARK: - Private functions

    private func fetchRemoteConfiguration() async throws -> Data {
        guard let appName = configuration.appName else {
            throw ConfigurationHandlerError.missingConfigurationAppName
        }

        let endpoint = RemoteConfigurationEndpoint(appName: appName)

        return try await apiClient.sendRequest(endpoint: endpoint)
    }
}
