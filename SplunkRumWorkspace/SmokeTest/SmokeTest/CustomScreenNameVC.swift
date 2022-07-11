//
//  CustomScreenNameVC.swift
//  multipleiOS_Versions
//
//  Created by Piyush Patil on 31/03/22.
//

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
