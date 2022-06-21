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
// Why not "import SplunkOtel"?  Because this links as a local framework, not as a swift package.
// FIXME align the framework name and directory names with the swift package name at some point
import SplunkRum

let email = "shattimare@splunk.com"
let pwd = "Password2@20202022"
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        SplunkRum.initialize(beaconUrl: "https://rum-ingest.us0.signalfx.com/v1/rum", rumAuth: "nF2sRwMTyB-is8WpcGQ72w", options: SplunkRumOptions(allowInsecureBeacon: true, debug: true,
            globalAttributes: [:], environment: nil, ignoreURLs: nil))
        
        getSessionToken()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    //get session token to fetch API
    func getSessionToken(){
        let url = URL(string: "https://api.us0.signalfx.com/v1/session")!

          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.addValue("application/json", forHTTPHeaderField: "Content-Type")
          request.addValue("X-SF-Token", forHTTPHeaderField: "SwATIe9ZVaTPdV8ZaK7l1w")
          
         // let sem = DispatchSemaphore(value: 0)
        let dict = ["email":email,"password":pwd]
        
            do {
                request.httpBody = try JSONEncoder().encode(dict)
            } catch {
                print(error)
            }

          let task = URLSession.shared.dataTask(with: request) { data, response, error in
              guard error == nil else {
                  print("Error: error calling DELETE")
                  print(error!)
                  return
              }
              guard let data = data else {
                  print("Error: Did not receive data")
                  return
              }
              guard let response = response as? HTTPURLResponse, (200 ..< 299) ~= response.statusCode else {
                  print("Error: HTTP request failed")
                  return
              }
              do {
                  guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                      print("Error: Cannot convert data to JSON")
                      return
                  }
                  guard let prettyJsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) else {
                      print("Error: Cannot convert JSON object to Pretty JSON data")
                      return
                  }
                  guard let prettyPrintedJson = String(data: prettyJsonData, encoding: .utf8) else {
                      print("Error: Could print JSON in String")
                      return
                  }
                  
                  print(prettyPrintedJson)
                  SplunkRum.setSessionToken(with: jsonObject["sf_accessToken"] as! String)  //accessToken
              } catch {
                  print("Error: Trying to convert JSON data to string")
                  return
              }
          }
          task.resume()
         // sem.wait()
          
      }

}

