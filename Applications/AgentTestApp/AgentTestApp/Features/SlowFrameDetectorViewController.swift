//
/*
Copyright 2024 Splunk Inc.

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

import SwiftUI
import UIKit

class SlowFrameDetectorViewController: UIViewController {

    @IBOutlet var slowFramesButton: UIButton!
    @IBOutlet var frozenFramesButton: UIButton!
    @IBOutlet var beatingHeartView: SlowFrameBeatingHeartView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func slowFramesClick(_ sender: UIButton) {
        // Sleep for 0.5 seconds on the main thread
        print("Sleeping for 0.5 seconds to force slow frames")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    @IBAction func frozenFramesClick(_ sender: UIButton) {
        // Sleep for 1 second on the main thread
        print("Sleeping for 2 seconds to force frozen frames")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
            Thread.sleep(forTimeInterval: 2.0)
        }
    }
}


