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

import Foundation

/// A dummy implementation of `URLSessionDataTask` for use in unit tests.
///
/// Allows manual overriding of `taskDescription` and `response` properties,
/// which is not possible with real `URLSessionDataTask` instances.
final class DummyDataTask: URLSessionDataTask {

    /// Backing storage for taskDescription property.
    private var _taskDescription: String?

    /// Overrides the `taskDescription` property for testing.
    override var taskDescription: String? {
        get { _taskDescription }
        set { _taskDescription = newValue }
    }

    /// Backing storage for response property.
    private var _response: URLResponse?

    /// Overrides the `response` property for testing.
    override var response: URLResponse? {
        get { _response }
        set { _response = newValue }
    }
}
