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

class ViewController: UIViewController, WKUIDelegate {

    var buttonID = 0

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
        buttonID = 0
        usleep(100 * 1000) // 100 ms
    }

    @IBAction
    func largeSleep() {
        var status = validateSpans()
        if !status {
            // If it is failing check one more time
            status = validateSpans()
            if !status {
                // If it is failing check one more time
                status = validateSpans()
            }
        }
        usleep(1000 * 1000) // 1000 ms
    }

}
