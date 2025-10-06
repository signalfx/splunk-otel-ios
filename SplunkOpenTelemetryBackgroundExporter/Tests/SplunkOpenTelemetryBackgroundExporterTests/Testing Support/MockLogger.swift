//
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

final class MockLogger: CiscoLogger.LogAgent, @unchecked Sendable {

    var poolName: String
    var category: String?

    var loggedMessages: [String] = []

    init() {
        self.poolName = "test"
        self.category = nil
    }

    init(poolName: String, category: String?) {
        self.poolName = poolName
        self.category = category
    }

    init(poolName: String, category: String?) async {
        self.poolName = poolName
        self.category = category
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    func process(configuration _: CiscoLogger.ConfigurationMessage) {}

    func log(level _: CiscoLogger.LogLevel, isPrivate _: Bool, message: @escaping @Sendable () -> String) {
        loggedMessages.append(message())
    }
}
