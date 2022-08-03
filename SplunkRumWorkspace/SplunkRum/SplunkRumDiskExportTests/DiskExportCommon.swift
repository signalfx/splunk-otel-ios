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

import Foundation
import Swifter
@testable import OpenTelemetrySdk
@testable import SplunkRum

fileprivate let idgen = RandomIdGenerator()

struct TestZipkinSpan: Decodable {
    var name: String
    var tags: [String: String]
}

enum SpanReceiverError: Error {
    case timeout(String)
}

class TestSpanReceiver {
    let server = HttpServer()
    var receivedSpans: [TestZipkinSpan] = []
    var started = false
    var receivedRequest = false

    init() {
        server["/v1/traces"] = { request in
            let spans = try! JSONDecoder().decode([TestZipkinSpan].self, from: Data(request.body))
            self.receivedSpans.append(contentsOf: spans)
            self.receivedRequest = true
            return HttpResponse.ok(.text("ok"))
        }

        server["/oops"] = { _ in
            self.receivedRequest = true
            return HttpResponse.internalServerError
        }
    }

    func start(_ port: UInt16) throws {
        if started {
            return
        }

        try server.start(port)
        started = true
    }

    func spans() -> [TestZipkinSpan] {
        return self.receivedSpans
    }

    func reset() {
        self.receivedRequest = false
        self.receivedSpans = []
    }

    func waitForSpans(timeoutSeconds: Int = 16) throws -> [TestZipkinSpan] {
        var secondsWaited = 0
        while !self.receivedRequest {
            sleep(1)
            secondsWaited += 1

            if secondsWaited >= timeoutSeconds {
                throw SpanReceiverError.timeout("Timed out waiting for spans")
            }
        }

        return spans()
    }
}

func makeSpan(name: String, timestamp: UInt64, tags: [String: String] = [:]) -> ZipkinSpan {
    ZipkinSpan(
        traceId: idgen.generateTraceId().hexString,
        parentId: nil,
        id: idgen.generateSpanId().hexString,
        kind: "CLIENT",
        name: name,
        timestamp: timestamp,
        duration: 1,
        remoteEndpoint: nil,
        annotations: [],
        tags: tags
    )
}

func makeSpanData(_ name: String) -> SpanData {
    SpanData(traceId: idgen.generateTraceId(), spanId: idgen.generateSpanId(), name: name, kind: .internal, startTime: Date(), endTime: Date())
}
