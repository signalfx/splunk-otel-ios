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

/// Validates if a string is a valid IPv4 or IPv6 address.
///
/// - Parameter ipString: The string to validate.
/// - Returns: `true` if the string is a valid IP address, `false` otherwise.
func isValidIPAddress(_ ipString: String) -> Bool {
    var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))

    // Try IPv4 validation using inet_pton
    if inet_pton(AF_INET, ipString, &buffer) == 1 {
        return true
    }

    // Try IPv6 validation using inet_pton
    if inet_pton(AF_INET6, ipString, &buffer) == 1 {
        return true
    }

    return false
}

/// Checks if a URLSession task is supported for instrumentation.
///
/// - Parameter task: The URLSessionTask to check.
/// - Returns: `true` if the task type is supported (data, download, or upload), `false` otherwise.
func isSupportedTask(task: URLSessionTask) -> Bool {
    task is URLSessionDataTask || task is URLSessionDownloadTask || task is URLSessionUploadTask
}

/// Checks if a URL should be excluded based on the excluded endpoints list.
///
/// Uses precise URL matching by comparing scheme, host, and path prefix to avoid false positives.
///
/// - Parameters:
///   - url: The URL to check.
///   - excludedEndpoints: List of endpoints that should be excluded from instrumentation.
/// - Returns: `true` if the URL matches an excluded endpoint, `false` otherwise.
func shouldExcludeURL(_ url: URL, excludedEndpoints: [URL]) -> Bool {

    for excludedEndpoint in excludedEndpoints {
        // Match scheme (both must be http or https, or exact match)
        let requestScheme = url.scheme?.lowercased() ?? ""
        let excludedScheme = excludedEndpoint.scheme?.lowercased() ?? ""
        guard requestScheme == excludedScheme else {
            continue
        }

        // Match host (exact match)
        let requestHost = url.host?.lowercased() ?? ""
        let excludedHost = excludedEndpoint.host?.lowercased() ?? ""
        guard requestHost == excludedHost else {
            continue
        }

        // Match port (if specified in excluded endpoint)
        if let excludedPort = excludedEndpoint.port {
            let requestPort = url.port ?? (requestScheme == "https" ? 443 : 80)
            guard requestPort == excludedPort else {
                continue
            }
        }

        // Match path (excluded endpoint path must be a prefix of request path)
        let requestPath = url.path
        let excludedPath = excludedEndpoint.path
        if excludedPath.isEmpty || excludedPath == "/" {
            // If excluded path is empty or "/", match any path on this host
            return true
        }
        if requestPath.hasPrefix(excludedPath) {
            return true
        }
    }
    return false
}

