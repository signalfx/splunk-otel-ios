//
//  TestUtils.swift
//  SplunkRumTests
//
//  Created by jbley on 2/23/21.
//

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
