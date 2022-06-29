//
//  rumSessionId.swift
//  multipleiOS_Versions
//
//  Created by Piyush Patil on 20/04/22.
//

import UIKit
import Swifter
import SplunkRum

class rumSessionId: UIViewController,UITableViewDelegate, UITableViewDataSource {
    
    var receivedSpans: [TestZipkinSpan] = []
    var receivedNativeSessionId: String?
    @IBOutlet var tableView: UITableView!
    let SLEEP_TIME: UInt32 = 7
    
    let indicator = UIActivityIndicatorView(style: .gray)
    let server = HttpServer()
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        indicator.center = view.center
        view.addSubview(indicator)
        indicator.startAnimating()
        
       // AppUtility.showLoaderWithText(text: "Loading..")
        DispatchQueue.main.async {
            
            do {
               
                try self.loadData()
                self.indicator.stopAnimating()
 
             } catch {
                 print(error)
             }
        }
        
                  
    }
    override func viewDidDisappear(_ animated: Bool) {
         resetTestEnvironment()
    }
    
    func loadData() throws {
        
        server["/"] = { request in
            print("... server got spans") //ZipkinSpan, TestZipkinSpan
            let spans = try! JSONDecoder().decode([TestZipkinSpan].self, from: Data(request.body))
            self.receivedSpans.append(contentsOf: spans)
            spans.forEach({ span in
                print(span)
            })
            return HttpResponse.ok(.text("ok"))
        }
        server["/session"] = { [self] request in
            receivedNativeSessionId = request.queryParams[0].1
            print("received session ID from js: "+receivedNativeSessionId!)
            return HttpResponse.ok(.text("ok"))
        }
       
        try server.start(8989)
        sleep(SLEEP_TIME)
        self.tableView.reloadData()
    }
    
    func resetTestEnvironment() {
        receivedSpans.removeAll()
        server.stop()
    }
    
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
     }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return receivedSpans.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell:CustomCell = self.tableView.dequeueReusableCell(withIdentifier: "CustomCell") as! CustomCell
        let dic = self.receivedSpans[indexPath.row]
        cell.lblName.text = dic.tags["splunk.rumSessionId"]?.description
        cell.lblSubtitle.text = dic.name
        cell.lblActionName.text = dic.tags["action.name"]?.description
        return cell
       
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            print("You tapped cell number \(indexPath.row).")
        let dic = self.receivedSpans[indexPath.row]
        //let traceid = dic.tags["splunk.rumSessionId"]?.description ?? "d1a8f3e2d7d3700c"
        
    }


}
struct TestZipkinSpan: Decodable {
    var name: String
   // var traceid: String
    var tags: [String: String]
    var annotations: [TestZipkinAnnotation]
}
struct TestZipkinAnnotation: Decodable {
    var value: String
    var timestamp: Int64
}

//func loadData() throws {
//
//    let server = HttpServer()
//    server["/"] = { request in
//        print("... server got spans")
//        let spans = try! JSONDecoder().decode([TestZipkinSpan].self, from: Data(request.body))
//        self.receivedSpans.append(contentsOf: spans)
//        spans.forEach({ span in
//            //print(span)
//        })
//        return HttpResponse.ok(.text("ok"))
//    }
////        server["/page.html"] = { _ in
////            let html = """
////                <div id="mydiv"></div>
////                <script>
////                    var text = "TEST MESSAGE<br>";
////                    try {
////                        var id = window.SplunkRumNative.getNativeSessionId();
////                        text += "SESSION ID IS "+id + "<br>";
////                        var idAgain = window.SplunkRumNative.getNativeSessionId();
////                        if (idAgain !== id) {
////                            text += "TEST ERROR SESSION ID CHANGED<br>";
////                        }
////                        fetch("http://127.0.0.1:8989/session?id="+id);
////                    } catch (e) {
////                        text += "TEST ERROR " + e.toString()+"<br>";
////                    }
////                    document.getElementById("mydiv").innerHTML = text;
////                </script>
////            """
////            return HttpResponse.ok(HttpResponseBody.html(html))
////        }
//    server["/session"] = { [self] request in
//        receivedNativeSessionId = request.queryParams[0].1
//        print("received session ID from js: "+receivedNativeSessionId!)
//        return HttpResponse.ok(.text("ok"))
//    }
//    try server.start(8989)
//    sleep(SLEEP_TIME)
//    print(receivedSpans.count)
//    tableView.reloadData()
//
//}
