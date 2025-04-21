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
import SplunkSharedProtocols
import SplunkAgent

class CustomTrackingViewController: UIViewController {

    @IBOutlet weak var trackEventButton: UIButton!
    @IBOutlet weak var trackErrorButton: UIButton!
    @IBOutlet weak var resultsView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Track Event

    @IBAction func trackEventClicked(_ sender: UIButton) {

        print("Track Event Clicked")
        let eventDict: [String: Any] = [
            "name": "universe",
            "meaning": 42
        ]
        let formatted = prettyFormat(eventDict)
        print(eventDict)
        resultsView.text = formatted


        // TODO: remove this example for WIP reference: SplunkRum.instance?.sessionReplay.recordingMask = RecordingMask(elements: [MaskElement]())

        SplunkRum.instance?.customTracking.trackEvent(name: "someEvent", attributes: eventDict)

    }

    // MARK: - Track Error

    @IBAction func trackErrorClicked(_ sender: UIButton) {
        print("Track Error Clicked")
    }

    func prettyFormat(_ attributes: [String: Any]) -> String {
        var formatted = ""
        for (key, value) in attributes {
            formatted += "\(key): \(String(describing: value))\n"
        }
        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
