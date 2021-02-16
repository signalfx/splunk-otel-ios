import Foundation
import XCTest
import Swifter
import SplunkRum

// Fake span structure for JSONDecoder, only care about tags at the moment
struct TestZipkinSpan: Decodable {
    var name: String
    var tags: [String: String]
}

class NetworkInstrumentationTests: XCTestCase {
    func testStuff() throws {
        let server = HttpServer()
        server["/data"] = { _ in
            return HttpResponse.ok(.text("here is some data"))
        }
        var spans: [TestZipkinSpan]?
        server["/v1/traces"] = { request in
            spans = try! JSONDecoder().decode([TestZipkinSpan].self, from: Data(request.body))
            return HttpResponse.ok(.text("ok"))
        }
        server["/error"] = { _ in
            return HttpResponse.internalServerError
        }
        try server.start(8989)
        defer { server.stop() }

        SplunkRum.initialize(beaconUrl: "http://127.0.0.1:8989/v1/traces", rumAuth: "FAKE", options: SplunkRumOptions(allowInsecureBeacon: true))

        // Not going to exhaustively test all the api variations, particularly since
        // they all flow through the same bit of code
        URLSession.shared.dataTask(with: URL(string: "http://127.0.0.1:8989/data")!) { (_, _: URLResponse?, _) in
            print("got /data")
        }.resume()
        var req = URLRequest(url: URL(string: "http://127.0.0.1:8989/error")!)
        req.httpMethod = "POST"
        URLSession.shared.uploadTask(with: req, from: "sample data".data(using: .utf8)!).resume()

        // FIXME config option to dial back the batch period
        print("sleeping to wait for span batch, don't worry about the pause...")
        sleep(8)
        print(spans as Any)
        let appStart = spans?.first(where: { (span) -> Bool in
            return span.name == "AppStart"
        })
        let httpGet = spans?.first(where: { (span) -> Bool in
            return span.name == "HTTP GET"
        })
        let httpPost = spans?.first(where: { (span) -> Bool in
            return span.name == "HTTP POST"
        })
        XCTAssertEqual(3, spans?.count)
        XCTAssertNotNil(appStart) // FIXME might as well assert some of these too

        XCTAssertNotNil(httpGet)
        XCTAssertEqual(httpGet?.tags["http.url"], "http://127.0.0.1:8989/data")
        XCTAssertEqual(httpGet?.tags["http.method"], "GET")
        XCTAssertEqual(httpGet?.tags["http.status_code"], "200")
        XCTAssertEqual(httpGet?.tags["http.response_content_length_uncompressed"], "17")

        XCTAssertNotNil(httpPost)
        XCTAssertEqual(httpPost?.tags["http.url"], "http://127.0.0.1:8989/error")
        XCTAssertEqual(httpPost?.tags["http.method"], "POST")
        XCTAssertEqual(httpPost?.tags["http.status_code"], "500")
        XCTAssertEqual(httpPost?.tags["http.request_content_length"], "11")

    }
}
