//
//  RUMInitializationVC.swift
//  multipleiOS_Versions
//
//  Created by Piyush Patil on 31/03/22.
//

import UIKit


class RUMInitializationVC: UIViewController {
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
    }
    
  

    @IBAction func httpCall(_ sender:Any){
        let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "NetworkRequestVC") as? NetworkRequestVC
        self.navigationController?.pushViewController(vc!, animated: true)
    }
    
    @IBAction func forceCrash(_ sender:Any){
        let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "CrashVC") as? CrashVC
        self.navigationController?.pushViewController(vc!, animated: true)
    }
    
    @IBAction func screenNameChange(_ sender:Any){
        let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "ScreenTrackVC") as? ScreenTrackVC
        self.navigationController?.pushViewController(vc!, animated: true)
    }
    
    @IBAction func webView(_ sender:Any){
        let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "WKWebViewVC") as? WKWebViewVC
        self.navigationController?.pushViewController(vc!, animated: true)
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
struct Log: TextOutputStream {

    func write(_ string: String) {
        let fm = FileManager.default
        let log = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("log.txt")
        print(log)
        if let handle = try? FileHandle(forWritingTo: log) {
            handle.seekToEndOfFile()
            handle.write(string.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? string.data(using: .utf8)?.write(to: log)
        }
    }
}
