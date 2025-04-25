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
import SplunkLogger
import SplunkSharedProtocols

public final class CustomTracking {

    public static var instance = CustomTracking()

    // MARK: - Private Properties

    private var eventTracking = EventTracking()
    private var errorTracking = ErrorTracking()
    private let internalLogger = InternalLogger(configuration: .default(subsystem: "SplunkCustomTracking", category: "Data"))

    // Shared state
    public unowned var sharedState: AgentSharedState?
    private var module: CustomTracking?
    private var onPublishBlock: ((CustomTrackingMetadata, CustomTrackingData) -> Void)?


    // Module conformance
    public required init() {}

    // MARK: - Initialization

    public init(sharedState: AgentSharedState? = nil) {
        self.sharedState = sharedState
    }

    internal func setModule(_ module: CustomTracking) {
        self.module = module
    }

    // MARK: - Public API

    /// Track a custom event.
    public func trackCustomEvent(_ name: String, _ attributes: [String: EventAttributeValue]) {
        internalLogger.log(level: .info) { "Tracking custom event: \(name) with attributes: \(attributes)" }
        module?.track(name: name, attributes: attributes)
    }

    /// Track an error with optional attributes.
    public func trackError(_ message: String, _ attributes: [String: EventAttributeValue] = [:]) {
        internalLogger.log(level: .error) { "Tracking error: \(message) with attributes: \(attributes)" }
        //let internalIssue = SplunkIssue(from: message)
        //errorTracking.track(internalIssue)
        module?.track(name: "Error", attributes: ["message": message, "attributes": attributes])
    }

    /// Track an Error object with optional attributes.
    public func trackError(_ error: Error, _ attributes: [String: EventAttributeValue] = [:]) {
        internalLogger.log(level: .error) { "Tracking error: \(error) with attributes: \(attributes)" }
        //let internalIssue = SplunkIssue(from: error)
        //errorTracking.track(internalIssue)
        module?.track(name: "Error", attributes: ["error": error, "attributes": attributes])
    }

    /// Track an NSError object with optional attributes.
    public func trackError(_ error: NSError, _ attributes: [String: EventAttributeValue] = [:]) {
        internalLogger.log(level: .error) { "Tracking NSError: \(error) with attributes: \(attributes)" }
        //let internalIssue = SplunkIssue(from: error)
        //errorTracking.track(internalIssue)
        module?.track(name: "NSError", attributes: ["error": error, "attributes": attributes])
    }

    /// Track an NSException object with optional attributes.
    public func trackException(_ exception: NSException, _ attributes: [String: EventAttributeValue] = [:]) {
        internalLogger.log(level: .error) { "Tracking NSException: \(exception) with attributes: \(attributes)" }
        //let internalIssue = SplunkIssue(from: exception)
        //errorTracking.track(internalIssue)
        module?.track(name: "NSException", attributes: ["exception": exception, "attributes": attributes])
    }
}
