//
/*
Copyright 2021 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import UIKit
import Foundation
import OpenTelemetrySdk
import SplunkRum

class RUMInitializationVC: UIViewController {

    @IBOutlet weak var lblSuccess: UILabel!
    @IBOutlet weak var lblFailed: UILabel!
    @IBOutlet weak var btnCustom: UIButton!
    @IBOutlet weak var btnError: UIButton!
    @IBOutlet weak var btnResignActive: UIButton!
    @IBOutlet weak var btnEnterForeground: UIButton!

    var buttonID = 0

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func validateSpans() -> Bool {
        var status = false
        switch self.buttonID {
        case 0:
            status = sdk_initialize_validation()
        case 2:
            status = crashSpan_validation()
        case 5:
            status = customSpan_validation()
        case 6:
            status = errorSpan_validation()
        case 7:
            status = resignActiveSpan_validation()
        case 8:
            status = enterForeGroundSpan_validation()
        case 9:
            status = appTerminateSpan_validation()
        default:
            status = false
        }
        return status
    }

    @IBAction func btnSDKInitializeValidation(_ sender: Any) {
        buttonID = 0
    }
    @IBAction func btnSpanValidation(_ sender: Any) {
        var status = validateSpans()
        if !status {
            // If it is failing check one more time
            status = validateSpans()
            if !status {
                // If it is failing check one more time
                status = validateSpans()
            }
        }
        self.lblSuccess.isHidden = !status
        self.lblFailed.isHidden = status
    }

    @IBAction func httpCall(_ sender: Any) {
        let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "NetworkRequestVC") as? NetworkRequestVC
        self.navigationController?.pushViewController(vc!, animated: true)
    }

    @IBAction func forceCrash(_ sender: Any) {
        buttonID = 2
        let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "CrashVC") as? CrashVC
        self.navigationController?.pushViewController(vc!, animated: true)
    }

    @IBAction func screenNameChange(_ sender: Any) {
        let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "ScreenTrackVC") as? ScreenTrackVC
        self.navigationController?.pushViewController(vc!, animated: true)
    }

    @IBAction func webView(_ sender: Any) {
        let tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "APMI-1779")
        let span = tracer.spanBuilder(spanName: "WebView").startSpan()
        SplunkRum.setGlobalAttributes(["HTML-file-name": "sample1"])
        span.end() // or use defer for this
        let vc = UIStoryboard.init(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "WKWebViewVC") as? WKWebViewVC
        self.navigationController?.pushViewController(vc!, animated: true)
    }
    @IBAction func customSpan(_ sender: Any) {
        buttonID = 5
        btnCustom.backgroundColor = UIColor.green
        btnError.backgroundColor = UIColor.lightGray
        btnResignActive.backgroundColor = UIColor.lightGray
        btnEnterForeground.backgroundColor = UIColor.lightGray

        let tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "APMI-1779")
        let span = tracer.spanBuilder(spanName: "CustomSpan").startSpan()
        span.end() // or use defer for this

    }
    @IBAction func errorSpan(_ sender: Any) {
        buttonID = 6
        btnError.backgroundColor = UIColor.green
        btnCustom.backgroundColor = UIColor.lightGray
        btnResignActive.backgroundColor = UIColor.lightGray
        btnEnterForeground.backgroundColor = UIColor.lightGray

        do {
            let htmlPath = Bundle.main.path(forResource: "sample4", ofType: "html")

            try isFileAvailableAt(resourcePath: htmlPath ?? "sample4.html")
        } catch CustomError.notFound {
             // SplunkRum.reportError(string: "File not exist.")
            self.reportStringErrorSpan(e: "File not exist.")

        } catch {
            // other error
        }
    }
    func reportStringErrorSpan(e: String) {
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
    func isFileAvailableAt(resourcePath: String) throws {
        if FileManager.default.fileExists(atPath: resourcePath) {
            print("file is exist at path")
        } else {
            throw CustomError.notFound
        }
    }
    @IBAction func resignActiveSpan(_ sender: Any) {
        buttonID = 7
        btnResignActive.backgroundColor = UIColor.green
        btnError.backgroundColor = UIColor.lightGray
        btnCustom.backgroundColor = UIColor.lightGray
        btnEnterForeground.backgroundColor = UIColor.lightGray
        span(with: "ResignActive")

    }
    @IBAction func enterBGSpan(_ sender: Any) {
        buttonID = 8
        btnEnterForeground.backgroundColor = UIColor.green
        btnError.backgroundColor = UIColor.lightGray
        btnCustom.backgroundColor = UIColor.lightGray
        btnResignActive.backgroundColor = UIColor.lightGray
        span(with: "EnterForeground")

    }
    @IBAction func terminateSpan(_ sender: Any) {
        buttonID = 9
        span(with: "AppTerminating")
        /*let now = Date()
        let tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "APMI-1779")
        let span = tracer.spanBuilder(spanName: "AppTerminating").setStartTime(time: now).startSpan()
        span.setAttribute(key: "component", value: "AppLifecycle")
        span.end(time: now)*/

    }
    func span(with name: String) {
        let now = Date()
        let tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "APMI-1779")
        let span = tracer.spanBuilder(spanName: name).setStartTime(time: now).startSpan()
        span.setAttribute(key: "component", value: "app-lifecycle")
        span.end(time: now)
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
enum CustomError: Error {
    case notFound
    case incorrectPassword
    case unexpected(code: Int)

}
extension CustomError: CustomStringConvertible {
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
