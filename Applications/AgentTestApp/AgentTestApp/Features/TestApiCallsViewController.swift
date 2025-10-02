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

class TestApiCallsViewController: UIViewController {

    // MARK: - UI Outlets

    @IBOutlet
    private var cloudkartNetworkButton1: UIButton!

    @IBOutlet
    private var cloudkartNetworkButton2: UIButton!

    @IBOutlet
    private var cloudkartNetworkButton3: UIButton!

    @IBOutlet
    private var cloudkartNetworkButton4: UIButton!

    @IBOutlet
    private var cloudkartNetworkButton5: UIButton!


    // MARK: - UI Actions

    @IBAction
    private func cloudkartNetworkClick1(_: UIButton) {
        let urlToCall = "http://appdynamics-cloudkart-demo.e2e.appd-test.com/orders/v1/cart"
        let body: [String: Any] = ["id": "leeza.sinha@gmail.com"]
        let httpBody = try? JSONSerialization.data(withJSONObject: body)
        let net = TestApiCalls()

        if let httpBody {
            net.simplePostWith(targetURL: urlToCall, body: httpBody)
        }
    }

    @IBAction
    private func cloudkartNetworkClick2(_: UIButton) {
        let urlToCall = "http://appdynamics-cloudkart-demo.e2e.appd-test.com/orders/v1/cart/count"

        let net = TestApiCalls()
        net.simpleGetWith(targetURL: urlToCall)
    }

    @IBAction
    private func cloudkartNetworkClick3(_: UIButton) {
        let urlToCall = "http://appdynamics-cloudkart-demo.e2e.appd-test.com/orders/v1/cart/count"
        let body: [String: Any] = ["name": "leeza2"]
        let httpBody = try? JSONSerialization.data(withJSONObject: body)
        let net = TestApiCalls()

        if let httpBody {
            net.simplePutWith(targetURL: urlToCall, body: httpBody)
        }
    }

    @IBAction
    private func cloudkartNetworkClick4(_: UIButton) {
        let urlToCall = "http://appdynamics-cloudkart-demo.e2e.appd-test.com/inventory/v1/items/count"
        let net = TestApiCalls()
        net.simpleGetWith(targetURL: urlToCall)
    }

    @IBAction
    private func cloudkartNetworkClick5(_: UIButton) {
        let urlToCall = "http://appdynamics-cloudkart-demo.e2e.appd-test.com/inventory/v1/warehouses"
        let net = TestApiCalls()
        net.simpleGetWith(targetURL: urlToCall)
    }
}
