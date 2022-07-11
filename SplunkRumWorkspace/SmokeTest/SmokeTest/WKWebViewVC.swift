//
//  WKWebViewVC.swift
//  multipleiOS_Versions
//
//  Created by Piyush Patil on 31/03/22.
//

import UIKit
import WebKit
import SplunkRum
import OpenTelemetrySdk

class WKWebViewVC: UIViewController {

    @IBOutlet var web: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        let link = URL(string:"https://developer.apple.com/videos/play/wwdc2019/239/")!
//        let request = URLRequest(url: link)
//        SplunkRum.integrateWithBrowserRum(web)
//        web.load(request)
        loadWebView(withFile: "sample1")
    
    }
    
    func loadWebView(withFile name : String){
        print("web view is loading using sample1.html....")
        let webView = WKWebView(frame: .zero)
        
        let htmlPath = Bundle.main.path(forResource: name, ofType: "html")

        let htmlUrl = URL(fileURLWithPath: htmlPath!)

       // let request = URLRequest(url: htmlUrl)

      //  webView.load(request)
        view = webView
        let tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "APMI-1779")
        let span = tracer.spanBuilder(spanName: "WebView").startSpan()
        SplunkRum.setGlobalAttributes(["HTML-file-name" : name])
        SplunkRum.integrateWithBrowserRum(webView)
        webView.loadFileURL(htmlUrl, allowingReadAccessTo: htmlUrl)
        span.end() // or use defer for this

        
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

