import SwiftUI
import SplunkOtel
import Swifter

var receivedSpans: [TestZipkinSpan] = []

struct TestZipkinSpan: Decodable {
    var name: String
    var tags: [String: String]
}

typealias SpanCallback = (TestZipkinSpan) -> Void

class PublishedState: ObservableObject {
    @Published var numSpans: Int = 0
    var spans: [TestZipkinSpan] = []
    var listeners: [SpanCallback] = []
    
    func receiveSpans(spans: [TestZipkinSpan]) {
        DispatchQueue.main.async {
            self.numSpans += spans.count
            for listener in self.listeners {
                for span in spans {
                    listener(span)
                }
            }
        }
    }
    
    func clear() {
        self.numSpans = 0
        self.spans = []
    }
    
    func onSpan(_ on: @escaping SpanCallback) {
        self.listeners.append(on)
    }
}

var globalState = PublishedState()
let receiverUrl = "http://127.0.0.1:8989"

func receiverEndpoint(_ route: String) -> String {
    return "\(receiverUrl)\(route)"
}

@main
struct SauceLabsTestAppApp: App {

    init() {
        let server = HttpServer()

        server["/v1/traces"] = { request in
            let spans = try! JSONDecoder().decode([TestZipkinSpan].self, from: Data(request.body))
            receivedSpans.append(contentsOf: spans)
            globalState.receiveSpans(spans: spans)
            return HttpResponse.ok(.text("ok"))
        }
        
        server["/upload"] = { request in
            let body = String(decoding: Data(request.body), as: UTF8.self)
            return HttpResponse.ok(.text(body))
        }
        
        server["/"] = { _ in
            return HttpResponse.ok(.text("hello"))
        }

        try! server.start(8989)
        
        SplunkRum.initialize(
            beaconUrl: receiverEndpoint("/v1/traces"),
            rumAuth: "FAKE_RUM_AUTH",
            options: SplunkRumOptions(
                allowInsecureBeacon: true,
                debug: true,
                globalAttributes: [:]
            )
        )
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
    }
}
