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

@testable import SplunkInteractions

final class TestInteractionDestination: SplunkInteractionsDestination {

    var didReceiveInteractionCallCount = 0
    var didReceiveFrustrationCallCount = 0
    var actionName: String?
    var lastFrustrationXpath: String?

    func sendInteraction(
        actionName: String,
        elementId _: String?,
        xpath _: String?,
        time _: Date
    ) {
        self.actionName = actionName
        didReceiveInteractionCallCount += 1
    }

    func sendFrustration(
        xpath: String?,
        time _: Date
    ) {
        lastFrustrationXpath = xpath
        didReceiveFrustrationCallCount += 1
    }
}
