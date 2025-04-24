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

import CiscoInteractions
import CiscoSwizzling
import Foundation
import SplunkLogger
import SplunkSharedProtocols

/// Handles interaction events and send them into destination.
public final class SplunkInteractions {
    
    // MARK: - Private properties

    private var interactionsDetector: InteractionsDetector<DefaultSwizzling>?
    private let internalLogger = InternalLogger(configuration: .interactions(category: "Module"))


    // MARK: - Initialization

    // Module conformance
    public required init() {}


    // MARK: - Instrumentation
    
    /// Start detecting interaction events.
    func startInteractionsDetection() {
        guard interactionsDetector == nil else {
            internalLogger.log(level: .error) {
                "Interactions detection is already running."
            }
            return
        }

        Task {
            do {
                interactionsDetector = try await InteractionsDetector<DefaultSwizzling>()
            } catch {
                internalLogger.log(level: .error) {
                    "Could not initialize InteractionsDetector: \(error)."
                }
            }
        }
    }
}
