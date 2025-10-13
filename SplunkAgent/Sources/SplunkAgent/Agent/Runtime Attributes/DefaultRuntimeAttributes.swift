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
internal import SplunkCommon

/// The class implements default runtime attributes for the agent.
final class DefaultRuntimeAttributes: AgentRuntimeAttributes {

    // MARK: - Internal

    private unowned let owner: SplunkRum
    private let accessQueue: DispatchQueue


    // MARK: - Private

    /// Internal value store for custom attributes.
    private var customValue: [String: Any]

    /// Persistent, unique identifier for this application installation.
    private let appInstallationId: String


    // MARK: - RuntimeAttributes protocol

    /// A list of attributes to use at signal start.
    ///
    ///  This list also contains custom attributes.
    var all: [String: Any] {
        var allAttributes: [String: Any] = [:]

        // Attributes added directly should come from sources
        // that are thread-safe themselves
        var systemAttributes: [String: Any] = [:]
        systemAttributes["user.anonymous_id"] = userIdentifier()
        systemAttributes["session.id"] = sessionIdentifier()
        systemAttributes["app.installation.id"] = installationIdentifier()
        allAttributes = systemAttributes


        let customAttributes = custom

        // Custom attributes will only be added if needed
        if !customAttributes.isEmpty {
            allAttributes = systemAttributes.merging(custom) { current, _ in
                current
            }
        }

        return allAttributes
    }


    // MARK: - AgentRuntimeAttributes protocol

    var custom: [String: Any] {
        accessQueue.sync {
            customValue
        }
    }

    func updateCustom(named: String, with value: Any) {
        accessQueue.async(flags: .barrier) {
            self.customValue[named] = value
        }
    }

    func removeCustom(named: String) {
        accessQueue.async(flags: .barrier) {
            self.customValue[named] = nil
        }
    }


    // MARK: - Initialization

    init(for owner: SplunkRum) {
        self.owner = owner
        customValue = [:]

        let queueName = PackageIdentifier.default(named: "runtimeAttributesAccess")
        accessQueue = DispatchQueue(label: queueName, qos: .userInitiated)

        let storage = UserDefaultsStorage()
        let storageKeyForAppInstallationId = "app.installation.id"

        // Retrieve or generate a persistent app installation ID
        if let existingAppInstallationId: String = try? storage.read(forKey: storageKeyForAppInstallationId), !existingAppInstallationId.isEmpty {
            appInstallationId = existingAppInstallationId
        }
        else {
            let newId = String.uniqueHexIdentifier(ofLength: 32)
            try? storage.update(newId, forKey: storageKeyForAppInstallationId)
            appInstallationId = newId
        }
    }


    // MARK: - Private methods

    private func userIdentifier() -> String? {
        // We only identify users if tracking is not prohibited
        guard owner.currentUser.trackingMode != .noTracking else {
            return nil
        }

        return owner.currentUser.userIdentifier
    }

    private func sessionIdentifier() -> String? {
        owner.currentSession.currentSessionId
    }

    private func installationIdentifier() -> String {
        appInstallationId
    }
}
