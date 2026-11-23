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
import SplunkCommon

@testable import SplunkAgent

final class DefaultSessionTestBuilder {

    // MARK: - Basic builds

    static func build(named: String) throws -> DefaultSession {
        // Build session with preconfigured storage
        let storage = UserDefaultsStorageTestBuilder.buildCleanStorage(named: named)
        let sessionModel = SessionsModel(storage: storage)
        return DefaultSession(sessionsModel: sessionModel, heldSessionStarts: buildHeldSessionStarts(named: named))
    }


    // MARK: - Held session starts

    /// Builds a store of held session starts in a clean temporary directory derived from `named`,
    /// so that tests never write the agent's production file.
    static func buildHeldSessionStarts(named: String) -> HeldSessionStartStore {
        HeldSessionStartStore(storage: buildCleanHeldStartsStorage(named: named))
    }

    /// Builds file storage in a temporary directory derived from `named`, removing what an earlier run left there.
    static func buildCleanHeldStartsStorage(named: String) -> FileKeyValueStorage {
        let testsDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("\(PackageIdentifier.default).tests")
        let directory = testsDirectory.appendingPathComponent(named, isDirectory: true)

        // Clean storage before test run
        try? FileManager.default.removeItem(at: directory)

        return FileKeyValueStorage(directory: directory)
    }
}
