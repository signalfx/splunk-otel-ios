//
//  CustomScreenNameVC.swift
//  multipleiOS_Versions
//
//  Created by Piyush Patil on 31/03/22.
//

import UIKit
import SplunkRum

class CustomScreenNameVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        SplunkRum.setScreenName("CustomScreenNameVC")
        // Do any additional setup after loading the view.
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
