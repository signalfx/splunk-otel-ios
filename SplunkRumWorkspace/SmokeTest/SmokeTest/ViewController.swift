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

import UIKit
import WebKit
import SplunkRum
import OpenTelemetrySdk

class ViewController: UIViewController, WKUIDelegate {

    var buttonID = 0
    @IBOutlet weak var lblSuccess: UILabel!
    @IBOutlet weak var lblFailed: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    func validateSpans() -> Bool {
        var status = false
        switch self.buttonID {
        case 0:
            status = sdk_initialize_validation()
        case 2:
            status = crashSpan_validation()
        case 5:
            status = customSpan_validation()
        case 6:
            status = errorSpan_validation()
        case 7:
            status = resignActiveSpan_validation()
        case 8:
            status = enterForeGroundSpan_validation()
        case 9:
            status = appTerminateSpan_validation()
        case 10:
            status = slowFrame_validation()
        case 11:
            status = frozenframe_validation()
        default:
            status = false
        }
        return status
    }

    @IBAction
    func clickMe() {
        print("I was clicked!")
        SplunkRum.setScreenName("CustomScreenName")

        let webview = WKWebView(frame: .zero)
        webview.uiDelegate = self
        let url = URL(string: "http://127.0.0.1:8989/page.html")
        let req = URLRequest(url: url!)
        view = webview
        SplunkRum.integrateWithBrowserRum(webview)
        webview.load(req)
    }

    @IBAction
    func smallSleep() {
        usleep(100 * 1000) // 100 ms
        buttonID = 0
    }

    @IBAction
    func largeSleep() {
        usleep(1000 * 1000) // 1000 ms
        buttonID = 0
    }
    @IBAction func btnSpanValidation(_ sender: Any) {

        var status = validateSpans()
        if !status {
            // If it is failing check one more time
            status = validateSpans()
            if !status {
                // If it is failing check one more time
                status = validateSpans()
            }
        }

        self.lblSuccess.isHidden = !status
        self.lblFailed.isHidden = status

    }

    func span(with name: String) {
        let now = Date()
        let tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "Sauce_labs")
        let span = tracer.spanBuilder(spanName: name).setStartTime(time: now).startSpan()
        span.setAttribute(key: "component", value: "app-lifecycle")
        span.end(time: now)
    }
}
