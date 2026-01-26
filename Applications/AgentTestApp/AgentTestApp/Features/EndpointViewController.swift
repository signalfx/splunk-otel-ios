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
    private var endpointRealm: UITextField!

    @IBOutlet
    private var endpointToken: UITextField!


    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Display the current endpoint values if configured
        if let currentRealm = SplunkRum.shared.state.endpointConfiguration?.realm {
            endpointRealm.text = currentRealm
        }
        else {
            endpointRealm.text = ""
            endpointRealm.placeholder = "No realm configured"
        }
        if let currentToken = SplunkRum.shared.state.endpointConfiguration?.rumAccessToken {
            endpointToken.text = currentToken
        }
        else {
            endpointToken.text = ""
            endpointToken.placeholder = "No token configured"
        }
    }


    // MARK: - UI Actions

    @IBAction
    private func setEndpoint(_: UIButton) {
        guard let newEndpointRealm = endpointRealm.text else {
            return
        }
        guard let newEndpointToken = endpointToken.text else {
            return
        }

        print("Reset Endpoint to \(newEndpointRealm)")

        let endpoint = EndpointCalls()
        endpoint.resetEndpoint(realm: newEndpointRealm, token: newEndpointToken)
    }

    @IBAction
    private func clearEndpoint(_: UIButton) {
        let endpoint = EndpointCalls()
        endpoint.clearEndpoint()

        print("Endpoint cleared")
    }
}
