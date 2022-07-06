//
//  RUMInitializationVC.swift
//  multipleiOS_Versions
//
//  Created by Piyush Patil on 31/03/22.
//

import UIKit
import SplunkRum
import OpenTelemetrySdk


class RUMInitializationVC: UIViewController {
    @IBOutlet weak var btnCustom: UIButton!
    @IBOutlet weak var btnError: UIButton!
    @IBOutlet weak var btnBgFg: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global(qos: .background).async {
            let server = FileServer(port: 8080)
            server.start()
        }

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
    @IBAction func customSpan(_ sender:Any){
        btnCustom.backgroundColor = UIColor.green
        btnError.backgroundColor = UIColor.systemGray5
        let tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "APMI-1779")
          let span = tracer.spanBuilder(spanName: "CustomSpan").startSpan()
          span.end() // or use defer for this
    }
    @IBAction func errorSpan(_ sender:Any){
        btnError.backgroundColor = UIColor.green
        btnCustom.backgroundColor = UIColor.systemGray5
//        let exception: NSException = NSException(name:NSExceptionName(rawValue: "Error span"), reason:"reason", userInfo:nil)
//        SplunkRum.reportError(exception: exception)
        do {
            let htmlPath = Bundle.main.path(forResource: "sample4", ofType: "html")

            try isFileAvailableAt(resourcePath: htmlPath ?? "sample4.html")
        }
        catch CustomError.notFound {
             //SplunkRum.reportError(string: "File not exist.")
            self.reportStringErrorSpan(e: "File not exist.")
        }
        catch {
            //other error
        }
    }
    func reportStringErrorSpan(e: String) {
       // let tracer = buildTracer()
        let tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "APMI-1779")
        let now = Date()
        let typeName = "SplunkRum.reportError(String)"
        let span = tracer.spanBuilder(spanName: typeName).setStartTime(time: now).startSpan()
        span.setAttribute(key: "component", value: "error")
        span.setAttribute(key: "error", value: true)
        span.setAttribute(key: "exception.type", value: "String")
        span.setAttribute(key: "exception.message", value: e)
        span.end(time: now)
    }
    func isFileAvailableAt(resourcePath : String) throws {
        if FileManager.default.fileExists(atPath: resourcePath){
            print("file is exist at path")
        }
        else{
            throw CustomError.notFound
        }
    }
    @IBAction func resignActiveSpan(_ sender:Any){
        btnBgFg.backgroundColor = UIColor.green
//        if UIApplication.shared.applicationState == .active {
//            DispatchQueue.main.asyncAfter(deadline: .now()) {
//                      UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
//            }
//        } else if UIApplication.shared.applicationState == .inactive {
//            DispatchQueue.main.asyncAfter(deadline: .now()) {
//                      UIApplication.shared.perform(#selector(NSXPCConnection.resume))
//            }
//        }
        
    }
    @IBAction func terminateSpan(_ sender:Any){
        exit(0)
        //UIApplication.shared.perform(#selector(NSXPCConnection.resume))
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

enum CustomError : Error {
    case notFound
    case incorrectPassword
    case unexpected(code:Int)

}
extension CustomError : CustomStringConvertible{
    public var description: String {
        switch self {
        case .notFound:
            return "File is not exist at path"
        case .incorrectPassword:
            return "Provided password is not corrent"
        case .unexpected(let code):
            return "Unexpected error occur"
        }
    }
    
}
