//
/*
Copyright 2025 Splunk Inc.

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

class EndpointViewController: UIViewController {

    // MARK: - UI Outlets

    @IBOutlet
    private var simpleNetworkButton: UIButton!

    @IBOutlet
    private var delegateNetworkButton: UIButton!

    @IBOutlet
    private var sampleUrl: UITextField!


    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let savedUrl = UserDefaults.standard.string(forKey: "SampleURL") ?? "https://httpbin.org/get"
        sampleUrl.text = savedUrl
    }


    // MARK: - UI Actions

    @IBAction
    private func setEndpoint(_: UIButton) {
        guard let urlToCall = sampleUrl.text else {
            return
        }

        UserDefaults.standard.set(urlToCall, forKey: "SampleURL")
        print("Simple Network Call to \(urlToCall)")

        let net = EndpointCalls()
        net.resetEndpoint(targetURL: urlToCall)
    }

    @IBAction
    private func clearEndpoint(_: UIButton) {
        let net = EndpointCalls()
        net.clearEndpoint()
        print("Endpoint cleared")
    }
}
