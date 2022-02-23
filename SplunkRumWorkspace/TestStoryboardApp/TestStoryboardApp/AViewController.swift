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
import UIKit
import SplunkRum

class AViewController: UIViewController, NSURLConnectionDelegate, NSURLConnectionDataDelegate {
    var data = NSMutableData()

    @IBAction public func aAction() {
        print("a action")
    }
    @IBAction public func callAsynchronousWebService() {
        print("NSURLConnection - Call")
        let url = URL(string: "http://127.0.0.1:7878/data")!  // failure and get error
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        NSURLConnection.sendAsynchronousRequest(req, queue: OperationQueue.main) {(_, data, _) in
            guard let data = data else { return }
            print(data)
        }
    }
    @IBAction public func callSynchronousWebService() {
        print("NSURLConnection - Call")
        // post method check
        let url = URL(string: "http://127.0.0.1:7878/data")! // sucess 500 "https://www.google.com"
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        // let parameters = "email=dj@gmail.com&password=DhaJiv1!&returnSecureToken=true"
        // let postData =  parameters.data(using: .utf8)
        // req.httpBody = postData
        var response: URLResponse? = URLResponse()
        //_ = try? NSURLConnection.sendSynchronousRequest(req, returning: &response)
        do {
            _ = try? NSURLConnection.sendSynchronousRequest(req, returning: &response)
        } catch {
            print(error)
        }
        }
   }
