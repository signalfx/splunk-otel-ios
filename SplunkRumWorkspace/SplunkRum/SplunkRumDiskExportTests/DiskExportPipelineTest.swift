//
/*
Copyright 2021 Splunk Inc.

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

import XCTest
@testable import SplunkRum

func rumOptions() -> SplunkRumOptions {
    let options = SplunkRumOptions()
    options.debug = true
    options.allowInsecureBeacon = true
    options.enableDiskCache = true
    return options
}

class DiskExportPipelineTest: XCTestCase {
    func testExportPipeline() throws {
        let receiver = TestSpanReceiver()
        try receiver.start(9733)
        XCTAssertTrue(
            SplunkRum.initialize(beaconUrl: "http://localhost:9733/v1/traces", rumAuth: "FAKE", options: rumOptions())
        )

        buildTracer().spanBuilder(spanName: "test").startSpan().end()

        sleep(11)

        let spans = receiver.spans()
        XCTAssertGreaterThan(spans.count, 0)
        XCTAssertTrue(spans.contains(where: { s in
            s.name == "test"
        }))
    }
}
