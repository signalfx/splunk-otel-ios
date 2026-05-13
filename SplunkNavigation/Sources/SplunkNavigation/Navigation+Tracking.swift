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
        track(screen: name, attributes: nil)
    }

    public func track(screen name: String, attributes: [String: Any]?) {
        let start = Date()

        guard runtimeStateStore.moduleEnabled else {
            return
        }

        let screenStateUpdate = updateCurrentScreenState(
            screenName: name,
            attributes: attributes,
            forceEmit: true
        )
        publishScreenNameChange(name)
        send(
            screenName: name,
            lastScreenName: screenStateUpdate.previousName,
            start: start,
            attributes: attributes
        )
    }
}
