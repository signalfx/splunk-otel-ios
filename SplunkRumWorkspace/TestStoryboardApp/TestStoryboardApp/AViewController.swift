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

class AViewController: UIViewController,NSURLConnectionDelegate,NSURLConnectionDataDelegate {
    
    var data = NSMutableData()

    @IBAction public func aAction() {
        print("a action")
    }
    
    @IBAction public func callAsynchronousWebService() {
        print("NSURLConnection - Call")
      
        //method 1
    /*  // let url = URL(string: "https://www.google.com")! //sucess check
        let url = URL(string: "http://www.splunk.com")! // failure check
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
       
        let connection : NSURLConnection = NSURLConnection(request: request as URLRequest, delegate: self,startImmediately: false)!
        connection.start()*/
        
        
        //method - 2
       // let url = URL(string: "http://www.splunk.com")! // sucess,status = 200 check  req.httpMethod = "GET"
        //let url = URL(string: "https://www.google.com")! //sucess , status = 200
       // let url = URL(string: "https://mock.codes/200")!// sucess 500
       
        let url = URL(string: "http://127.0.0.1:7878/data")!  //failure and get error
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        NSURLConnection.sendAsynchronousRequest(req, queue: OperationQueue.main) {(response, data, error) in
            guard let data = data else { return }
            print(data)
        }
    }
       
        @IBAction public func callSynchronousWebService() {
            print("NSURLConnection - Call")
          
            //method 1
        /*  // let url = URL(string: "https://www.google.com")! //sucess check
            let url = URL(string: "http://www.splunk.com")! // failure check
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
           
            let connection : NSURLConnection = NSURLConnection(request: request as URLRequest, delegate: self,startImmediately: false)!
            connection.start()*/
            
            
            //method - 2
          //  let url = URL(string: "http://www.splunk.com")! // sucess check 200 req.httpMethod = "GET"
           // let url = URL(string: "https://www.google.com")! //sucess but 200 not proper data
            
          //  let url = URL(string: "http://127.0.0.1:7878/data")!  //error check and proper data == "HEAD"
          /*  let url = URL(string: "https://mock.codes/200")!// sucess 500
            var req = URLRequest(url: url)
            req.httpMethod = "GET"  //"GET" //"HEAD"*/
            
            //post method check
            let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=AIzaSyBdq5A4lktKz4herj2cxXum2TSAHiqeuAs")!// sucess 500
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            
            let parameters = "email=dj@gmail.com&password=DhaJiv1!&returnSecureToken=true"
            let postData =  parameters.data(using: .utf8)
            req.httpBody = postData
               
            
            var response: URLResponse? = URLResponse()
           

          
            let urlData = try? NSURLConnection.sendSynchronousRequest(req, returning: &response)
            
         
        
        
    }
   
    func connection(_ connection: NSURLConnection, didFailWithError error: Error){
        print("Error is there...")
    }
    
    // NSURLconnectiondatadelegate
    func connection(connection: NSURLConnection, didReceiveResponse response: URLResponse)
    {
        self.data = NSMutableData()
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData)
    {
        self.data.append(data as Data)
    }
    func connectionDidFinishLoading(connection: NSURLConnection)
    {
        print("connection finished")
    }
    
    
}
