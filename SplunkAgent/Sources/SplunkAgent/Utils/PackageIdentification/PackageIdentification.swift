//
/*
Copyright 2024 Splunk Inc.

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

/// Defines a basic set of properties for identifying a package.
protocol PackageIdentification {

    // MARK: - Static constants

    /// Basic package identification.
    ///
    /// It should follow the conventions used for Bundle Identifier.
    static var `default`: String { get }


    // MARK: - Identification

    /// Creates combined identifier based on `default` identifier
    /// and its extension defined with `named`.
    ///
    /// - Parameter named: A `String` with identifier extension.
    ///
    /// - Returns: A newly assembled `String` with an extended identifier
    ///             or default identifier if the extension part is empty.
    static func `default`(named: String) -> String
}
