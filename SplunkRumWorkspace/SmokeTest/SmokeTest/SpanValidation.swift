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
	

import Foundation

var LOG_FILE_URL : String! {
    return getLogFileURL()
}

let INITIALIZE_SPAN = "Span SplunkRum.initialize"
let APP_START_SPAN = "Span AppStart"
let PRESENTATION_SPAN = "Span PresentationTransition"
let POST_SPAN = "Span HTTP POST"
let GET_SPAN = "Span HTTP GET"
let PUT_SPAN = "Span HTTP PUT"
let DELETE_SPAN = "Span HTTP DELETE"
let NETWORK_CALL_POST_URL = "https://reqres.in/api/login"
let NETWORK_CALL_DELETE_URL = "https://my-json-server.typicode.com/typicode/demo/posts/1"
let NETWORK_CALL_GET_URL = "https://www.splunk.com"
let NETWORK_CALL_PUT_URL = "https://reqres.in/api/users/2"

let SCREEN_CHANGE_SPAN = "Span screen name change"
let SHOWVC_SPAN = "Span ShowVC"
let SCREEN_TRACK_VC = "ScreenTrackVC"
let CUSTOME_SCREEN_TRACK_VC = "CustomScreenNameVC"
let CUSTOM_SPAN = "Span CustomSpan"
let ERROR_SPAN = "Span SplunkRum.reportError(String)"
let RESIGNACTIVE_SPAN = "Span ResignActive"
let ENTERFOREGROUND_SPAN = "Span EnterForeground"
let APPTERMINATE_SPAN = "Span AppTerminating"
let CRASH_SPAN = "Span SIGTRAP"
let WEBVIEW_SPAN = "Span WebView"
let BUNDLE_ID = "com.splunk.opentelemetry.SmokeTest"


func getLogFileURL() -> String {
    
    let allPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    let documentsDirectory = allPaths.first!
    let pathForLog = (documentsDirectory as NSString).appending("/logs.txt")
    return pathForLog
    
}

func screen_track_validation() -> Bool {
    
    guard !(read_log_file().error) else {return false}
    let str = read_log_file().content
    print(str)
    if str.contains(SCREEN_CHANGE_SPAN) && str.contains(SHOWVC_SPAN) && str.contains(SCREEN_TRACK_VC) && str.contains(CUSTOME_SCREEN_TRACK_VC) {
        return true
    } else {
        print("No Logs found...")
        return false
    }
    
}

// Validating the RUM SDK initialize span.
func sdk_initialize_validation() -> Bool {
    guard !(read_log_file().error) else {return false}
    let str = read_log_file().content
    if str.contains(INITIALIZE_SPAN) && str.contains(APP_START_SPAN) && str.contains(PRESENTATION_SPAN) {
        return true
    } else {
        print("No Logs found...")
        return false
    }
}

func method_post_validation() -> Bool {
    guard !(read_log_file().error) else {return false}
    let str = read_log_file().content
    if str.contains(POST_SPAN) && str.contains(NETWORK_CALL_POST_URL) {
        return true
    } else {
        print("No Logs found...")
        return false
    }
}

func method_get_validation() -> Bool {
    guard !(read_log_file().error) else {return false}
    let str = read_log_file().content
    if str.contains(GET_SPAN) && str.contains(NETWORK_CALL_GET_URL) {
        return true
    } else {
        print("No Logs found...")
        return false
    }
}

func method_put_validation() -> Bool {
    guard !(read_log_file().error) else {return false}
    let str = read_log_file().content
    if str.contains(PUT_SPAN) && str.contains(NETWORK_CALL_PUT_URL) {
        return true
    } else {
        print("No Logs found...")
        return false
    }
}

func method_delete_validation() -> Bool {
    guard !(read_log_file().error) else {return false}
    let str = read_log_file().content
    if str.contains(DELETE_SPAN) && str.contains(NETWORK_CALL_DELETE_URL) {
        return true
    } else {
        print("No Logs found...")
        return false
    }
}

func read_log_file() -> (content:String,error:Bool) {
    let file = "logs.txt"

    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fileURL = dir.appendingPathComponent(file)
        print("#########")
        print(fileURL)
        do {
            let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
            return (content:fileContent,error:false)
        }
        catch { print("not able to read logs")}
    }
    
    return (content:"",error:true)

}

func delete_logs() {
    do {
        try FileManager.default.removeItem(at: URL.init(fileURLWithPath: LOG_FILE_URL))
        print("All Logs are deleted...")
    } catch {
        print("Failed to delete logs...")
    }
}
func clear_logs() {
    let text = ""
    do {
         try text.write(toFile: LOG_FILE_URL, atomically: false, encoding: .utf8)
    } catch {
         print(error)
    }
}
func customSpan_validation()-> Bool {
    guard !(read_log_file().error) else {return false}
    let str = read_log_file().content
    if str.contains(CUSTOM_SPAN){
        return true
    } else {
        print("No Logs found...")
        return false
    }
}
func errorSpan_validation()-> Bool {
    guard !(read_log_file().error) else {return false}
    let str = read_log_file().content
    if str.contains(ERROR_SPAN){
        return true
    } else {
        print("No Logs found...")
        return false
    }
}
func resignActiveSpan_validation() -> Bool{
    guard !(read_log_file().error) else {return false}
    let str = read_log_file().content
    print(str)
    if str.contains(RESIGNACTIVE_SPAN){
        return true
    } else {
        print("No Logs found...")
        return false
    }
}
func enterForeGroundSpan_validation()-> Bool {
    guard !(read_log_file().error) else {return false}
    let str = read_log_file().content
    if str.contains(ENTERFOREGROUND_SPAN){
        return true
    } else {
        print("No Logs found...")
        return false
    }
}
func appTerminateSpan_validation()-> Bool {
    guard !(read_log_file().error) else {return false}
    let str = read_log_file().content
    if str.contains(APPTERMINATE_SPAN){
        return true
    } else {
        print("No Logs found...")
        return false
    }
}
func crashSpan_validation()-> Bool {
    let str = read_log_file().content
    if str.contains(CRASH_SPAN){
        return true
    } else {
        print("No Logs found...")
        return false
    }
}
func webViewSpan_validation() -> Bool{
    let str = read_log_file().content
    if str.contains(WEBVIEW_SPAN){
        return true
    } else {
        print("No Logs found...")
        return false
    }
}
