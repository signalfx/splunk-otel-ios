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

class CrashVC: UIViewController {

    @IBOutlet weak var btnCrashOnLoad: UIButton!
    @IBOutlet weak var btnForceCrash: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    @IBAction func click_NextVC(_sender: Any) {
        btnCrashOnLoad.backgroundColor = UIColor.green
        btnForceCrash.backgroundColor = UIColor.gray

        let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "CreshOnViewDidloadVC") as? CreshOnViewDidloadVC
        self.navigationController?.pushViewController(vc!, animated: true)
    }

    @IBAction func click_Error(_sender: Any) {
        btnCrashOnLoad.backgroundColor = UIColor.gray
        btnForceCrash.backgroundColor = UIColor.green
        let null = UnsafePointer<UInt8>(bitPattern: 0)
        let derefNull = null!.pointee
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
