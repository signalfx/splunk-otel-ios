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

import CiscoInteractions
import Foundation

/// Abstracts a node in the view hierarchy for the purpose of XPath construction.
///
/// This protocol exists to decouple the XPath generation logic from `InteractionViewNode`,
/// enabling testability via mock implementations without importing the full interaction framework.
protocol ViewNodeRepresentable {
    var viewTypeName: String { get }
    var viewId: ObjectIdentifier { get }
    var indexPath: IndexPath? { get }
    var superNode: (any ViewNodeRepresentable)? { get }
}

extension InteractionViewNode: ViewNodeRepresentable {
    var superNode: (any ViewNodeRepresentable)? {
        superViewNode
    }
}
