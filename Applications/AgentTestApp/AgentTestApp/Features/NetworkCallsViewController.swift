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

class NetworkCallsViewController: UIViewController {

    @IBOutlet weak var simpleNetworkButton: UIButton!
    @IBOutlet weak var delegateNetworkButton: UIButton!
    @IBOutlet weak var sampleUrl: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let savedUrl = UserDefaults.standard.string(forKey: "SampleURL") ?? "https://httpbin.org/get"
        sampleUrl.text = savedUrl
    }

    @IBAction func simpleNetworkClick(_ sender: UIButton) {
        
        let urlToCall = sampleUrl.text!
        UserDefaults.standard.set(urlToCall, forKey:"SampleURL")
        print("Simple Network Call to \(urlToCall)")
        
        let net = NetworkCalls()
        net.simpleNetworkCallWith(targetURL: urlToCall)
    }
    @IBAction func delegateNetworkClick(_ sender: UIButton) {
        
        let urlToCall = sampleUrl.text!
        UserDefaults.standard.set(urlToCall, forKey:"SampleURL")
        print("Delegate Network Call to \(urlToCall)")
        
        let net = NetworkCalls()
        net.simpleNetworkCallWithDelegate(targetURL: urlToCall)
    }
    @IBAction func resetUrl(_ sender: UIButton) {
        
        let savedUrl = "https://httpbin.org/get"
        UserDefaults.standard.set(savedUrl, forKey:"SampleURL")
        sampleUrl.text = savedUrl
        print("Sample URL reset to \(savedUrl)")
    }
}


