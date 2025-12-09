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
import Testing

@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct OperationQueueConvenienceInitTests {

    @Test
    func checkInit() throws {
        let queue = OperationQueue("testQueue", maxConcurrents: 987, qualityOfService: .utility)

        #expect(queue.name == "com.otel.sdk.testQueue")
        #expect(queue.maxConcurrentOperationCount == 987)
        #expect(queue.qualityOfService == .utility)
    }
}
