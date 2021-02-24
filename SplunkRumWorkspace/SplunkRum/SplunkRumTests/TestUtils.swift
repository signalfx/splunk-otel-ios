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

var receivedSpans: [TestZipkinSpan] = []
let ServerPort = 8989
var testEnvironmentInited = false

func initializeTestEnvironment() throws {
    if testEnvironmentInited {
        receivedSpans.removeAll()
        return
    }
    testEnvironmentInited = true
    let server = HttpServer()
    server["/data"] = { _ in
        return HttpResponse.ok(.text("here is some data"))
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
    SplunkRum.initialize(beaconUrl: "http://127.0.0.1:8989/v1/traces", rumAuth: "FAKE", options: SplunkRumOptions(allowInsecureBeacon: true))

}
