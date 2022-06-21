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
        let traceid = dic.tags["splunk.rumSessionId"]?.description ?? "d1a8f3e2d7d3700c"
        getContentOfRecentTraceSegment(with: traceid)
    }
    func getContentOfRecentTraceSegment(with traceID:String){
      //  let str2 = "https://api.us0.signalfx.com/v2/apm/trace/d1a8f3e2d7d3700c/latest" //get content of recent trace segment
        let url = URL(string: "https://api.us0.signalfx.com/v2/apm/trace/d1a8f3e2d7d3700c/latest")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("X-SF-Token", forHTTPHeaderField: "nF2sRwMTyB-is8WpcGQ72w")
        
        let sem = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { _, _, error in
            if error != nil {
                print("failure")
            } else {
                print("success")
            }
            sem.signal()
        }
        task.resume()
        sem.wait()
        
    }
   /* public func export(spans: [SpanData]) -> SpanExporterResultCode {
      //  let str = "https://api.us0.signalfx.com/v2/apm/trace/d1a8f3e2d7d3700c/segments" //get all segment of trace id
       // let str1 = "https://api.us0.signalfx.com/v2/apm/trace/d1a8f3e2d7d3700c/1610500200000'" //get content of trace segment
        let str2 = "https://api.us0.signalfx.com/v2/apm/trace/d1a8f3e2d7d3700c/latest" //get content of recent trace segment
        guard let url = URL(string: self.options.endpoint) else { return .failure }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("X-SF-Token", forHTTPHeaderField: "nF2sRwMTyB-is8WpcGQ72w")
        options.additionalHeaders.forEach {
            request.addValue($0.value, forHTTPHeaderField: $0.key)
        }
        

       /* let spans = encodeSpans(spans: spans)
        do {
            request.httpBody = try JSONEncoder().encode(spans)
        } catch {
            return .failure
        }*/

        var status: SpanExporterResultCode = .failure

        let sem = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { _, _, error in
            if error != nil {
                status = .failure
            } else {
                status = .success
            }
            sem.signal()
        }
        task.resume()
        sem.wait()

        return status
    }*/

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
