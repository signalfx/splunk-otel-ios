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

/// The class implements a public API for the CustomTracking module.
@objc(SPLKCustomTrackingModule)
public final class CustomTrackingModuleObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC


    // MARK: - Track Custom Events

    /// Track a custom event with a name and attributes.
    ///
    /// - Parameter name: The event name assigned by the user.
    ///
    /// - Parameter attributes: Dictionary with `AttributeValueObjC` value.
    ///
    /// - Returns: The updated `CustomTrackingModuleObjC` instance.
    @discardableResult
    @objc public func trackCustomEvent(name: String, attributes: [String: AttributeValueObjC]) -> CustomTrackingModuleObjC {
        owner.agent.customTracking.trackCustomEvent(name, MutableAttributes(with: attributes))

        return self
    }


    // MARK: - Track Errors

    /// Track an error (NSString message) with attributes.
    ///
    /// - Parameter message: A concise summary of the error condition.
    ///
    /// - Parameter attributes: Dictionary with `AttributeValueObjC` value.
    ///
    /// - Returns: The updated `CustomTrackingModuleObjC` instance.
    @discardableResult
    @objc public func trackErrorMessage(message: String, attributes: [String: AttributeValueObjC]) -> CustomTrackingModuleObjC {
        owner.agent.customTracking.trackError(message, MutableAttributes(with: attributes))

        return self
    }

    /// Track an NSError with attributes.
    ///
    /// - Parameter error: An instance of a type conforming to `NSError`.
    ///
    /// - Parameter attributes: Dictionary with `AttributeValueObjC` value.
    ///
    /// - Returns: The updated `CustomTrackingModuleObjC` instance.
    @discardableResult
    @objc public func trackError(error: NSError, attributes: [String: AttributeValueObjC]) -> CustomTrackingModuleObjC {
        owner.agent.customTracking.trackError(error, MutableAttributes(with: attributes))

        return self
    }


    /// Track an NSException object with optional attributes.
    ///
    /// - Parameter exception: An NSException instance such as one caught after a throw.
    ///
    /// - Parameter attributes: Dictionary with `AttributeValueObjC` value.
    ///
    /// - Returns: The updated `CustomTrackingModuleObjC` instance.
    @discardableResult
    @objc public func trackException(exception: NSException, attributes: [String: AttributeValueObjC]) -> CustomTrackingModuleObjC {
        owner.agent.customTracking.trackException(exception, MutableAttributes(with: attributes))

        return self
    }


    // MARK: - Single argument helpers (signatures)

    @discardableResult
    @objc public func trackCustomEvent(name: String) -> CustomTrackingModuleObjC {
        owner.agent.customTracking.trackCustomEvent(name)

        return self
    }

    @discardableResult
    @objc public func trackErrorMessage(message: String) -> CustomTrackingModuleObjC {
        owner.agent.customTracking.trackError(message)

        return self
    }

    @discardableResult
    @objc public func trackError(error: NSError) -> CustomTrackingModuleObjC {
        owner.agent.customTracking.trackError(error)

        return self
    }

    @discardableResult
    @objc public func trackException(exception: NSException) -> CustomTrackingModuleObjC {
        owner.agent.customTracking.trackException(exception)

        return self
    }


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
