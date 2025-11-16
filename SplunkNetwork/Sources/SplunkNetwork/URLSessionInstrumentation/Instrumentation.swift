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

/// Manages network instrumentation state and coordination.
///
/// Encapsulates module registration, swizzling, and provides thread-safe access.
final class NetworkInstrumentationManager {

    // MARK: - Singleton

    static let shared = NetworkInstrumentationManager()

    // MARK: - Private Properties

    private var module: NetworkInstrumentation?
    private let queue = DispatchQueue(label: "com.splunk.networkModuleQueue")
    private var hasSwizzled = false

    /// Logger instance for network instrumentation.
    let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "NetworkInstrumentation")

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Thread-safe getter for the network module.
    ///
    /// - Returns: The current network module instance, or `nil` if not initialized.
    func getModule() -> NetworkInstrumentation? {
        queue.sync { module }
    }

    /// Thread-safe setter for the network module.
    ///
    /// - Parameter newModule: The network module instance to set.
    func setModule(_ newModule: NetworkInstrumentation?) {
        queue.sync {
            module = newModule
        }
    }

    /// Clears the network module pointer asynchronously.
    ///
    /// Safe to call from deinit without risking deadlock.
    func clearModule() {
        queue.async { [weak self] in
            self?.module = nil
        }
    }

    /// Initializes network instrumentation with the given module.
    ///
    /// This function sets up URLSession method swizzling to enable automatic
    /// HTTP request/response instrumentation. Swizzling only occurs once,
    /// even if this function is called multiple times.
    ///
    /// - Parameter module: The NetworkInstrumentation module to use for configuration.
    func initialize(with module: NetworkInstrumentation) {
        queue.sync {
            if !hasSwizzled {
                swizzleUrlSession()
                hasSwizzled = true
            }
            self.module = module
        }
    }
}
