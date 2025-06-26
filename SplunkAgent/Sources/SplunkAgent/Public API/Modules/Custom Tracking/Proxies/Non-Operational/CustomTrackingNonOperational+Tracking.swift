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
internal import CiscoLogger


/// Extensions implementing CustomTracking public API in non-operational mode.
///
/// This is especially the case when the module is stopped by remote configuration,
/// but we still need to keep the API available to the user.
extension CustomTrackingNonOperational {


    // MARK: - Implement logging-only functions

    @discardableResult func trackCustomEvent(_ name: String, _ attributes: MutableAttributes) -> any CustomTrackingModule {
        logAccess(toApi: "trackCustomEvent(name:attributes:)")
        return self
    }


    // MARK: - Track Errors

    @discardableResult func trackError(_ message: String, _ attributes: MutableAttributes = MutableAttributes()) -> any CustomTrackingModule {
        logAccess(toApi: "trackError(message:attributes:)")
        return self
    }

    @discardableResult func trackError(_ error: Error, _ attributes: MutableAttributes = MutableAttributes()) -> any CustomTrackingModule {
        logAccess(toApi: "trackError(error:attributes:)")
        return self
    }

    @discardableResult func trackException(_ exception: NSException, _ attributes: MutableAttributes = MutableAttributes()) -> any CustomTrackingModule {
        logAccess(toApi: "trackException(exception:attributes:)")
        return self
    }
}
