
import UIKit
import WebKit
import SplunkRum
import OpenTelemetrySdk

class WKWebViewVC: UIViewController {

    @IBOutlet var web: WKWebView!
    @IBOutlet weak var lblSuccess: UILabel!
    @IBOutlet weak var lblFailed: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadWebView(withFile: "sample1")
    
    }
    
    func loadWebView(withFile name : String){
        print("web view is loading using sample1.html....")
        let htmlPath = Bundle.main.path(forResource: name, ofType: "html")
        let htmlUrl = URL(fileURLWithPath: htmlPath!)
        SplunkRum.integrateWithBrowserRum(web)
        web.loadFileURL(htmlUrl, allowingReadAccessTo: htmlUrl)
        

        
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func btnSpanValidation(_ sender: Any) {
        DispatchQueue.main.async {
            let status = webViewSpan_validation()
            self.lblSuccess.isHidden = !status
            self.lblFailed.isHidden = status
        }
    }
    
}

