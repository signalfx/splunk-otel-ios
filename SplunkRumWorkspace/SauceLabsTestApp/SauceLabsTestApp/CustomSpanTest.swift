/*
Copyright 2023 Splunk Inc.

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
import SplunkOtel

class CustomSpanTest: TestCase {
    init() {
        super.init(name: "customSpan")
    }

    override func execute() {
        let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "customSpanTest", instrumentationVersion: nil)
        let span = tracer.spanBuilder(spanName: "customSpan").startSpan()
        span.setAttribute(key: "foo", value: "123")
        span.end()
    }

    override func verify(_ span: TestZipkinSpan) {
        if span.name != "customSpan" {
            return
        }

        if span.tags["foo"] != "123" {
            return self.fail()
        }
    }
}
