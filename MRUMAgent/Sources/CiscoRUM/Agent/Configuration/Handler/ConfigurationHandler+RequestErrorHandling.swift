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

    // MARK: - API Client request error handling

    func handleAPIClientError(_ error: APIClientError) {

        switch error {
        case let .server(serverDetail):
            setupReloadTimer(in: serverDetail.retryAfterMs)

            internalLogger.log(level: .warn) {
                """
                Fetching remote configuration failed with an internal server error. \n
                Status code: \(serverDetail.statusCode)
                Message: \(serverDetail.message)
                Retrying in \(serverDetail.retryAfterMs)ms.
                """
            }

        case .noData:
            internalLogger.log(level: .info) {
                "Fetching remote configuration failed with an empty server response."
            }

        case .sessionDataFailed:
            internalLogger.log(level: .info) {
                "Fetching remote configuration failed due to an internal `URLSession` error: \(error.localizedDescription)."
            }

        case let .statusCode(statusCode):
            internalLogger.log(level: .info) {
                "Fetching remote configuration failed with a non-success response code: \(statusCode)."
            }
        }
    }

    func handleConfigurationHandlerError(_ error: ConfigurationHandlerError) {

        switch error {
        case .missingConfigurationAppName:
            internalLogger.log(level: .info) {
                "Fetching remote configuration failed due to a missing application name."
            }
        }
    }

    func handleError(_ error: Error) {
        internalLogger.log(level: .info) {
            "Fetching remote configuration failed with an error: \(error.localizedDescription)"
        }
    }
}
