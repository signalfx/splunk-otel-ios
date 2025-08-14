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

import Foundation
import UIKit

class CrashesViewController: UIViewController {

    @IBAction func fatalErrorButtonClick(_ sender: UIButton) {

        print("Fatal Error Crash Selected")
        let crashes = Crashes()
        crashes.fatalErrorCrash()
    }

    @IBAction func preconditionButtonClick(_ sender: UIButton) {

        print("Precondition Crash Selected")
        let crashes = Crashes()
        crashes.preconditionCrash()
    }

    @IBAction func unwrapExceptionButtonClick(_ sender: UIButton) {

        print("Unwrap Exception Crash Selected")
        let crashes = Crashes()
        crashes.unwrapException()
    }

    @IBAction func infiniteLoopButtonClick(_ sender: UIButton) {

        print("Infinite Loop Crash Selected")
        let crashes = Crashes()
        crashes.infiniteLoop()
    }
}
