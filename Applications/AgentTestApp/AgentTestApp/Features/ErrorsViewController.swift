//
/*
Copyright 2026 Splunk Inc.

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

class ErrorsViewController: UIViewController {

    // MARK: - UI Actions

    @IBAction
    private func fatalErrorButtonClick(_: UIButton) {

        print("Fatal Error Crash Selected")
        let errors = Errors()
        errors.fatalErrorCrash()
    }

    @IBAction
    private func preconditionButtonClick(_: UIButton) {

        print("Precondition Crash Selected")
        let errors = Errors()
        errors.preconditionCrash()
    }

    @IBAction
    private func unwrapExceptionButtonClick(_: UIButton) {

        print("Unwrap Exception Crash Selected")
        let errors = Errors()
        errors.unwrapException()
    }

    @IBAction
    private func infiniteLoopButtonClick(_: UIButton) {

        print("Infinite Loop Crash Selected")
        let errors = Errors()
        errors.infiniteLoop()
    }
}
