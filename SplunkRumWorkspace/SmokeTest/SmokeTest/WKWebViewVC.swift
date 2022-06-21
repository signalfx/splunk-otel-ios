//
//  WKWebViewVC.swift
//  multipleiOS_Versions
//
//  Created by Piyush Patil on 31/03/22.
//

import UIKit
import WebKit
import SplunkRum

class WKWebViewVC: UIViewController {

    @IBOutlet var web: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()        
        let link = URL(string:"https://developer.apple.com/videos/play/wwdc2019/239/")!
        let request = URLRequest(url: link)
        SplunkRum.integrateWithBrowserRum(web)
        web.load(request)
    
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
