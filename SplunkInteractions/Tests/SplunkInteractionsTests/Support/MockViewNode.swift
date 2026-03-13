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

final class MockViewNode: ViewNodeRepresentable {

    let viewTypeName: String
    let viewId: ObjectIdentifier
    let indexPath: IndexPath?
    let superNode: (any ViewNodeRepresentable)?

    init(
        viewTypeName: String,
        viewId: ObjectIdentifier,
        indexPath: IndexPath? = nil,
        superNode: (any ViewNodeRepresentable)? = nil
    ) {
        self.viewTypeName = viewTypeName
        self.viewId = viewId
        self.indexPath = indexPath
        self.superNode = superNode
    }
}
