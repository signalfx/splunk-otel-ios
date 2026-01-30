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

    // MARK: - Private Properties

    private let endpointCalls = EndpointCalls()

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureEndpointFields()
    }

    // MARK: - UI Actions

    @IBAction
    private func setEndpoint(_: UIButton) {
        guard
            let realm = endpointRealm.text, !realm.isEmpty,
            let token = endpointToken.text, !token.isEmpty
        else {
            return
        }

        print("Reset Endpoint to \(realm)")
        endpointCalls.resetEndpoint(realm: realm, token: token)
    }

    @IBAction
    private func clearEndpoint(_: UIButton) {
        endpointCalls.clearEndpoint()
        print("Endpoint cleared")
    }

    // MARK: - Private Helpers

    private func configureEndpointFields() {
        let config = SplunkRum.shared.state.endpointConfiguration

        endpointRealm.text = config?.realm
        endpointRealm.placeholder = config?.realm == nil ? "No realm configured" : nil

        endpointToken.text = config?.rumAccessToken
        endpointToken.placeholder = config?.rumAccessToken == nil ? "No token configured" : nil
    }
}
