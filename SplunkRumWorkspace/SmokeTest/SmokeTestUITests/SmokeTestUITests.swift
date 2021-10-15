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
import Swifter

struct TestZipkinSpan: Decodable {
    var name: String
    var tags: [String: String]
    var annotations: [TestZipkinAnnotation]
}
struct TestZipkinAnnotation: Decodable {
    var value: String
    var timestamp: Int64
}
var receivedSpans: [TestZipkinSpan] = []
var receivedNativeSessionId: String?

class SmokeTestUITests: XCTestCase {

    // swiftlint:disable overridden_super_call
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    let SLEEP_TIME: UInt32 = 10 // batch is currently every 5 so this should be plenty

    func testStartup() throws {
        // UI tests must launch the application that they test.
        let server = HttpServer()
        server["/"] = { request in
            print("... server got spans")
            let spans = try! JSONDecoder().decode([TestZipkinSpan].self, from: Data(request.body))
            receivedSpans.append(contentsOf: spans)
            spans.forEach({ span in
                print(span)
            })
            return HttpResponse.ok(.text("ok"))
        }
        server["/page.html"] = { _ in
            let html = """
                <div id="mydiv"></div>
                <script>
                    var text = "TEST MESSAGE<br>";
                    try {
                        var id = window.SplunkRumNative.getNativeSessionId();
                        text += "SESSION ID IS "+id + "<br>";
                        var idAgain = window.SplunkRumNative.getNativeSessionId();
                        if (idAgain !== id) {
                            text += "TEST ERROR SESSION ID CHANGED<br>";
                        }
                        fetch("http://127.0.0.1:8989/session?id="+id);
                    } catch (e) {
                        text += "TEST ERROR " + e.toString()+"<br>";
                    }
                    document.getElementById("mydiv").innerHTML = text;
                </script>
            """
            return HttpResponse.ok(HttpResponseBody.html(html))
        }
        server["/session"] = { request in
            receivedNativeSessionId = request.queryParams[0].1
            print("received session ID from js: "+receivedNativeSessionId!)
            return HttpResponse.ok(.text("ok"))
        }
        try server.start(8989)

        let app = XCUIApplication()
        app.launch()
        sleep(SLEEP_TIME)

        // App start, initial presentation transition, etc.

        XCTAssert(receivedSpans.count > 2)
        let srInit = receivedSpans.first(where: { (span) -> Bool in
            return span.name == "SplunkRum.initialize"
        })
        XCTAssertNotNil(srInit)
        let appStart = receivedSpans.first(where: { (span) -> Bool in
            return span.name == "AppStart"
        })
        XCTAssertNotNil(appStart)
        XCTAssertNotNil(appStart?.annotations.first(where: { (annot) -> Bool in
            return annot.value == "process.start"
        }))
        XCTAssertNotNil(appStart?.annotations.first(where: { (annot) -> Bool in
            return annot.value == "UIApplicationDidFinishLaunchingNotification"
        }))
        XCTAssertNotNil(appStart?.annotations.first(where: { (annot) -> Bool in
            return annot.value == "UIApplicationWillEnterForegroundNotification"
        }))
        XCTAssertNotNil(appStart?.annotations.first(where: { (annot) -> Bool in
            return annot.value == "UIApplicationDidBecomeActiveNotification"
        }))
        let presTrans = receivedSpans.first(where: { (span) -> Bool in
            return span.name == "PresentationTransition"
        })
        XCTAssertNotNil(presTrans)
        XCTAssertEqual("ViewController", presTrans?.tags["screen.name"]?.description)

        // Switch apps and back cycle
        XCUIDevice.shared.press(XCUIDevice.Button.home)
        print("pressed home button")
        sleep(2)
        app.activate()
        print("app re-activated")
        sleep(SLEEP_TIME)

        let resign = receivedSpans.first(where: { (span) -> Bool in
            return span.name == "ResignActive"
        })
        XCTAssertNotNil(resign)

        let foreground = receivedSpans.first(where: { (span) -> Bool in
            return span.name == "EnterForeground"
        })
        XCTAssertNotNil(foreground)
        // should be in the same session
        XCTAssertEqual(resign?.tags["splunk.rumSessionId"]?.description, foreground?.tags["splunk.rumSessionId"]?.description)

        // IBAction
        app.buttons["CLICK ME"].tap()
        sleep(SLEEP_TIME)
        let action = receivedSpans.first(where: { (span) -> Bool in
            return span.name == "action"
        })
        XCTAssertNotNil(action)
        XCTAssertEqual("clickMe", action?.tags["action.name"]?.description)

        // the click also caused a setScreenName which should produce a span
        let screenName = receivedSpans.last(where: { (span) -> Bool in
            return span.name == "screen name change"
        })
        XCTAssertNotNil(screenName)
        XCTAssertEqual("ViewController", screenName?.tags["last.screen.name"]?.description)
        XCTAssertEqual("CustomScreenName", screenName?.tags["screen.name"]?.description)

        // The webview should now have rendered the page with a session ID embedded in it, and posted that back to us
        XCTAssertNotNil(receivedNativeSessionId)
        XCTAssertEqual(appStart?.tags["splunk.rumSessionId"]?.description, receivedNativeSessionId)

        // FIXME multiple screens, pickVC cases, etc.
    }

}
