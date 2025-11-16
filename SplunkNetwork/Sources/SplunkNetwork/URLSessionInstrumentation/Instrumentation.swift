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

import CiscoLogger
import Foundation
import SplunkCommon


/// Used to access ignoreURLs and excludedEndpoints.
private var networkModule: NetworkInstrumentation?
private let networkModuleQueue = DispatchQueue(label: "com.splunk.networkModuleQueue")

/// Thread-safe getter for the network module.
///
/// - Returns: The current network module instance, or `nil` if not initialized.
func getNetworkModule() -> NetworkInstrumentation? {
    networkModuleQueue.sync { networkModule }
}

/// Thread-safe setter for the network module.
///
/// - Parameter module: The network module instance to set.
func setNetworkModule(_ module: NetworkInstrumentation?) {
    networkModuleQueue.sync {
        networkModule = module
    }
}

/// Clears the network module pointer asynchronously.
/// Safe to call from deinit without risking deadlock.
func clearNetworkModule() {
    networkModuleQueue.async {
        networkModule = nil
    }
}

/// Logger instance for network instrumentation.
let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "NetworkInstrumentation")

/// Ensures swizzling only happens once, even if initializeNetworkInstrumentation is called multiple times.
private let swizzleOnce: Void = {
    swizzleUrlSession()
}()

/// Initializes network instrumentation with the given module.
///
/// This function sets up URLSession method swizzling to enable automatic
/// HTTP request/response instrumentation. Swizzling only occurs once,
/// even if this function is called multiple times.
///
/// - Parameter module: The NetworkInstrumentation module to use for configuration.
func initializeNetworkInstrumentation(module: NetworkInstrumentation) {
    _ = swizzleOnce
    setNetworkModule(module)
}
