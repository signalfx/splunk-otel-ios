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

/// Defines known types of navigation.
enum NavigationType: Sendable {
    case show
    case transition
}

/// The structure encapsulates one navigation in the client application.
struct NavigationPair: Sendable {

    // MARK: - Navigation identity

    let type: NavigationType


    // MARK: - Navigation life

    let start: Date
    var end: Date?


    // MARK: - Controller identity

    let typeName: String
    let screenName: String
}
