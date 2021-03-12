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

import Foundation
import Swifter
import SplunkRum
import OpenTelemetrySdk
import OpenTelemetryApi
import XCTest

var receivedSpans: [TestZipkinSpan] = []
let ServerPort = 8989
var testEnvironmentInited = false
var localSpans: [SpanData] = []

class TestSpanExporter: SpanExporter {
    func export(spans: [SpanData]) -> SpanExporterResultCode {
        localSpans.append(contentsOf: spans)
        return .success
    }

    func flush() -> SpanExporterResultCode { return .success }
    func shutdown() { }
}

func resetTestEnvironment() {
    receivedSpans.removeAll()
    localSpans.removeAll()
}

func initializeTestEnvironment() throws {
    if testEnvironmentInited {
        resetTestEnvironment()
        return
    }
    testEnvironmentInited = true
    let server = HttpServer()
    server["/data"] = { _ in
        let resp = HttpResponse.raw(200, "OK",
                         ["Server-Timing": "traceparent;desc=\"00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01\""]) { writer throws in
            try writer.write("here is some data".data(using: .utf8)!)
        }
        return resp
    }
    server["/v1/traces"] = { request in
        let spans = try! JSONDecoder().decode([TestZipkinSpan].self, from: Data(request.body))
        receivedSpans.append(contentsOf: spans)
        return HttpResponse.ok(.text("ok"))
    }
    server["/error"] = { _ in
        return HttpResponse.internalServerError
    }
    try server.start(8989)
    SplunkRum.initialize(beaconUrl: "http://127.0.0.1:8989/v1/traces", rumAuth: "FAKE", options: SplunkRumOptions(allowInsecureBeacon: true, debug: true, globalAttributes: ["strKey": "strVal", "intKey": 7, "doubleKey": 1.5, "boolKey": true]))
    OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(SimpleSpanProcessor(spanExporter: TestSpanExporter()))

    // FIXME config option to dial back the batch period
    print("sleeping to wait for span batch, don't worry about the pause...")
    sleep(8)
    // Should have received an AppStart; this will act as the only test for valid zipkin-on-the-wire
    let appStart = receivedSpans.first(where: { (span) -> Bool in
        return span.name == "AppStart"
    })
    let beacon = receivedSpans.first(where: { (span) -> Bool in
        return span.tags["http.url"]?.contains("/v1/traces") ?? false
    })
    XCTAssertNil(beacon)

    XCTAssertNotNil(appStart)
    XCTAssertNotNil(appStart?.tags["os.version"])
    XCTAssertNotNil(appStart?.tags["device.model"])
    // FIXME not a great place to shoehorn it currently, but checking the globalAttributes logic here
    XCTAssertEqual("7", appStart?.tags["intKey"])
    XCTAssertEqual("1.5", appStart?.tags["doubleKey"])
    XCTAssertEqual("true", appStart?.tags["boolKey"])
    XCTAssertEqual("strVal", appStart?.tags["strKey"])

    resetTestEnvironment()
}
