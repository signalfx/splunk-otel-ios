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

extension Navigation {

    // MARK: - Manual detection

    public func track(screen name: String) {

        // Legacy navigation POC
        // Track manual scren name in the legacy solution
        navigationLegacy.setManualScreenName(name)
        return

        let start = Date()

        Task {
            let moduleEnabled = await model.moduleEnabled
            let lastScreenName = await model.screenName

            guard moduleEnabled else {
                return
            }

            guard lastScreenName != name else {
                return
            }

            // The manual screen name takes priority over the detected name
            await model.update(screenName: name)
            await model.update(isManualScreenName: true)

            // Yield this change to the consumer
            continuation.yield(name)

            // Send corresponding span
            send(screenName: name, lastScreenName: lastScreenName, start: start)
        }
    }
}
