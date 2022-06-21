//
//  CrashVC.swift
//  multipleiOS_Versions
//
//  Created by Piyush Patil on 31/03/22.
//

import UIKit

class CrashVC: UIViewController {
    
    @IBOutlet weak var btnCrashOnLoad: UIButton!
    @IBOutlet weak var btnForceCrash: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()


    }
    
    @IBAction func click_NextVC(_sender:Any) {
        btnCrashOnLoad.backgroundColor = UIColor.green
        btnForceCrash.backgroundColor = UIColor.systemGray5
        
        let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "CreshOnViewDidloadVC") as? CreshOnViewDidloadVC
        self.navigationController?.pushViewController(vc!, animated: true)
    }
    
    @IBAction func click_Error(_sender:Any) {
        btnCrashOnLoad.backgroundColor = UIColor.systemGray5
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
