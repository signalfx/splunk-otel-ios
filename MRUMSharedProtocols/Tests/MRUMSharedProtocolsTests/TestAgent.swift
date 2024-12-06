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

@testable import MRUMSharedProtocols
import XCTest

public class TestAgent {
    let module: any Module

    public init(module: any Module) {
        self.module = module
        self.module.onPublish(data: receive)
    }

    public func receive(metadata: any ModuleEventMetadata, data: any ModuleEventData) {
        let metadata = metadata as? TestEventMetadata
        let data = data as? TestEventData

        if let metadata {
            // process the data
            module.deleteData(for: metadata)
        }

        XCTAssertNotNil(metadata)
        XCTAssertNotNil(data)
    }
}
