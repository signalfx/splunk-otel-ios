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

class WKWebViewVC: UIViewController {

    @IBOutlet var web: WKWebView!
    @IBOutlet weak var lblSuccess: UILabel!
    @IBOutlet weak var lblFailed: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        loadWebView(withFile: "sample1")

    }

    func loadWebView(withFile name: String) {
        let htmlPath = Bundle.main.path(forResource: name, ofType: "html")
        let htmlUrl = URL(fileURLWithPath: htmlPath!)
        SplunkRum.integrateWithBrowserRum(web)
        web.loadFileURL(htmlUrl, allowingReadAccessTo: htmlUrl)

    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func btnSpanValidation(_ sender: Any) {
        DispatchQueue.main.async {
            let status = webViewSpan_validation()
            self.lblSuccess.isHidden = !status
            self.lblFailed.isHidden = status
        }
    }

}
