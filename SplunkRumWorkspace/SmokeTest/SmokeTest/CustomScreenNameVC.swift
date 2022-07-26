//
/*
Copyright 2021 Splunk Inc.

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
import SplunkRum

class CustomScreenNameVC: UIViewController {

    @IBOutlet weak var lblSuccess: UILabel!
    @IBOutlet weak var lblFailed: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        SplunkRum.setScreenName("CustomScreenNameVC")
        // Do any additional setup after loading the view.
    }

    @IBAction func btnSpanValidation(_ sender: Any) {
        DispatchQueue.main.async {
            let status = screen_track_validation()
            self.lblSuccess.isHidden = !status
            self.lblFailed.isHidden = status
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
