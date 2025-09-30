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

import WebKit

/// A mock `WKUserContentController` to track calls to `addUserScript`, `addScriptMessageHandler`, and `removeScriptMessageHandler`.
final class MockWKUserContentController: WKUserContentController {
    var addUserScriptCalled = false
    var addUserScriptCallCount = 0
    var addScriptMessageHandlerCalled = false
    var removeScriptMessageHandlerCalled = false
    var lastAddedMessageHandlerName: String?

    override func addUserScript(_: WKUserScript) {
        addUserScriptCalled = true
        addUserScriptCallCount += 1
    }

    override func addScriptMessageHandler(_: WKScriptMessageHandlerWithReply, contentWorld _: WKContentWorld, name: String) {
        addScriptMessageHandlerCalled = true
        lastAddedMessageHandlerName = name
    }

    /// Override in the mock to prevent spurious calls to the
    /// real framework implementation.
    override func removeScriptMessageHandler(forName _: String) {
        removeScriptMessageHandlerCalled = true
    }
}
