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
import SplunkAgent

class EndpointCalls {

    // MARK: - Endpoint calls

    /// Updates the endpoint configuration with a custom trace URL.
    ///
    /// - Parameter targetURL: The URL string for the trace endpoint.
    /// - Returns: `true` if the endpoint was successfully updated, `false` otherwise.
    @discardableResult
    func resetEndpoint(targetURL: String) -> Bool {
        guard let url = URL(string: targetURL) else {
            print("EndpointCalls: Invalid URL string: \(targetURL)")
            return false
        }

        let endpoint = EndpointConfiguration(trace: url)

        do {
            try SplunkRum.shared.updateEndpoint(endpoint)
            print("EndpointCalls: Endpoint updated to \(url)")
            return true
        }
        catch {
            print("EndpointCalls: Failed to update endpoint: \(error)")
            return false
        }
    }

    /// Clears/disables the current endpoint configuration.
    ///
    /// After calling this method, spans will not be sent until a new endpoint is configured.
    func clearEndpoint() {
        SplunkRum.shared.disableEndpoint()
        print("EndpointCalls: Endpoint disabled")
    }
}
