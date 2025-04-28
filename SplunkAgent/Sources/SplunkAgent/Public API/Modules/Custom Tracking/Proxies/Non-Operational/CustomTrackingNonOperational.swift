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
internal import SplunkLogger


/// The class implementing CustomTracking public API in non-operational mode.
///
/// This is especially the case when the module is stopped by remote configuration,
/// but we still need to keep the API available to the user.
final class CustomTrackingNonOperational: CustomTrackingModule {


    // MARK: - Implement logging-only functions

    func trackCustomEvent(_ name: String, _ attributes: [String: Any]) {
        logAccess(toApi: "trackCustomEvent:name:attributes")
    }


    // MARK: - Track Errors

    func trackError(_ message: String, _ attributes: [String: Any]? = nil) {
        logAccess(toApi: "trackError:message:attributes")
    }

    func trackError(_ error: Error, _ attributes: [String: Any]? = nil) {
        logAccess(toApi: "trackError:error:attributes")
    }

    func trackError(_ nsError: NSError, _ attributes: [String: Any]? = nil) {
        logAccess(toApi: "trackError:nsError:attributes")
    }

    func trackException(_ exception: NSException, _ attributes: [String: Any]? = nil) {
        logAccess(toApi: "trackError:exception:attributes")
    }


    // MARK: - Private

    private let internalLogger: InternalLogger


    // MARK: - Initialization

    init() {
        internalLogger = InternalLogger(configuration: .agent(category: "CustomTracking Module (Non-Operational)"))
    }


    // MARK: - Logger

    func logAccess(toApi named: String) {
        internalLogger.log(level: .notice) {
            """
            Attempt to access the API of a remotely disabled CustomTracking module. \n
            API: `\(named)`
            """
        }
    }
}
