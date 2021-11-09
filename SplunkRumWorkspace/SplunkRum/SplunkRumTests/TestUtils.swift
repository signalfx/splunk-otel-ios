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

class TestSpanProcessor: SpanProcessor {
    var isStartRequired: Bool
    var isEndRequired: Bool
    var exporter: SpanExporter
    init(spanExporter: SpanExporter) {
        self.exporter = spanExporter
        isStartRequired = false
        isEndRequired = true
    }

    func onStart(parentContext: SpanContext?, span: ReadableSpan) { }
    func onEnd(span: ReadableSpan) {
        exporter.export(spans: [span.toSpanData()])
    }

    func shutdown() { }
    func forceFlush(timeout: TimeInterval?) { }

}

class TestSpanExporter: SpanExporter {
    var exportSucceeds = true

    func export(spans: [SpanData]) -> SpanExporterResultCode {
        if exportSucceeds {
            localSpans.append(contentsOf: spans)
            return .success
        } else {
            return .failure
        }
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
    server["/ignore_this"] = { _ in
        return HttpResponse.ok(HttpResponseBody.text("OK"))
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
    let options = SplunkRumOptions()
    options.debug = true
    options.allowInsecureBeacon = true
    options.globalAttributes = ["strKey": "strVal", "intKey": 7, "doubleKey": 1.5, "boolKey": true]
    options.environment = "env"
    options.ignoreURLs = try! NSRegularExpression(pattern: ".*ignore_this.*")

    SplunkRum.initialize(beaconUrl: "http://127.0.0.1:8989/v1/traces", rumAuth: "FAKE", options: options)
    OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(TestSpanProcessor(spanExporter: TestSpanExporter()))

    print("sleeping to wait for span batch, don't worry about the pause...")
    sleep(8)
    // Should have received a SplunkRum.initialize; this will act as the only test for valid zipkin-on-the-wire
    let srInit = receivedSpans.first(where: { (span) -> Bool in
        return span.name == "SplunkRum.initialize"
    })
    let beacon = receivedSpans.first(where: { (span) -> Bool in
        return span.tags["http.url"]?.contains("/v1/traces") ?? false
    })
    XCTAssertNil(beacon)

    XCTAssertNotNil(srInit)
    // Checking the globalAttributes logic just once here
    XCTAssertEqual("appstart", srInit?.tags["component"]?.description)
    XCTAssertEqual("7", srInit?.tags["intKey"])
    XCTAssertEqual("1.5", srInit?.tags["doubleKey"])
    XCTAssertEqual("true", srInit?.tags["boolKey"])
    XCTAssertEqual("strVal", srInit?.tags["strKey"])
    XCTAssertNotNil(srInit?.tags["config_settings"])
    XCTAssertEqual("env", srInit?.tags["environment"])

    resetTestEnvironment()
}
