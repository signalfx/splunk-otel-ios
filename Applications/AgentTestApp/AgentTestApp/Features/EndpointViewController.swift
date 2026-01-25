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

import SplunkAgent
import UIKit

class EndpointViewController: UIViewController {

    // MARK: - UI Outlets

    @IBOutlet
    private var resetEndpointButton: UIButton!

    @IBOutlet
    private var clearEndpointButton: UIButton!

    @IBOutlet
    private var endpointUrl: UITextField!


    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Display the current endpoint URL if configured
        if let currentUrl = SplunkRum.shared.state.endpointConfiguration?.traceEndpoint {
            endpointUrl.text = currentUrl.absoluteString
        }
        else {
            endpointUrl.text = ""
            endpointUrl.placeholder = "No endpoint configured"
        }
    }


    // MARK: - UI Actions

    @IBAction
    private func setEndpoint(_: UIButton) {
        guard let newEndpointUrl = endpointUrl.text else {
            return
        }

        print("Reset Endpoint to \(newEndpointUrl)")

        let endpoint = EndpointCalls()
        endpoint.resetEndpoint(targetURL: newEndpointUrl)
    }

    @IBAction
    private func clearEndpoint(_: UIButton) {
        let endpoint = EndpointCalls()
        endpoint.clearEndpoint()

        print("Endpoint cleared")
    }
}
