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

/// A mock `WKWebViewConfiguration` that provides a `MockWKUserContentController`.
final class MockWKWebViewConfiguration: WKWebViewConfiguration {
    /// Hold a private instance of our mock to ensure it's the one being used.
    private let mockUCC = MockWKUserContentController()

    /// Override as a mutable computed property to match the superclass.
    override var userContentController: WKUserContentController {
        get {
            mockUCC
        }
        set {
            // The setter is required to match the superclass property, but we can ignore it
            // since we always want to return our specific mock instance.
        }
    }
}
