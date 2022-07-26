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
import Alamofire
import AFNetworking
import Foundation

// swiftlint:disable type_body_length
class NetworkRequestVC: UIViewController {

    @IBOutlet weak var btnAFNetworking: UIButton!
    @IBOutlet weak var btnAlamofire: UIButton!
    @IBOutlet weak var btnurlsession: UIButton!
    @IBOutlet weak var networkCallView: UIView!
    @IBOutlet weak var btnClose: UIButton!

    @IBOutlet weak var btnPost: UIButton!
    @IBOutlet weak var btnGet: UIButton!
    @IBOutlet weak var btnDelete: UIButton!
    @IBOutlet weak var btnPut: UIButton!

    @IBOutlet weak var lblSuccess: UILabel!
    @IBOutlet weak var lblFailed: UILabel!

    var strCompare: String = String()
    var typeOfAPIMethod: String!

    let manager = AFHTTPSessionManager()
    let params: Parameters = ["name": "Nicole", "job": "iOS Developer"]
    let parameters: Parameters = ["email": "eve.holt@reqres.in", "password": "cityslicka"]

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        btnClose.setTitle("", for: .normal)
        networkCallView.isHidden = true
        networkCallView.layer.borderWidth = 2
        networkCallView.layer.cornerRadius = 5
        networkCallView.layer.masksToBounds = true
        networkCallView.layer.borderColor = UIColor.red.cgColor

    }

    @IBAction func urlSession(_ sender: Any) {
        strCompare = "URLSession"
        UIView.transition(with: networkCallView, duration: 0.6,
                options: .transitionCrossDissolve,
                animations: {self.networkCallView.isHidden = false
        })

        btnurlsession.backgroundColor = UIColor.green
        btnAlamofire.backgroundColor = UIColor.gray
        btnAFNetworking.backgroundColor = UIColor.gray
        reloadNetWorkCallView()
    }

    @IBAction func Alamofire(_ sender: Any) {
        strCompare = "Alamofire"
        UIView.transition(with: networkCallView, duration: 0.6,
                options: .transitionCrossDissolve,
                animations: {self.networkCallView.isHidden = false
        })
        btnurlsession.backgroundColor = UIColor.gray
        btnAlamofire.backgroundColor = UIColor.green
        btnAFNetworking.backgroundColor = UIColor.gray
        reloadNetWorkCallView()
    }

    @IBAction func AFnetworking(_ sender: Any) {
        strCompare = "AFNetworking"
        UIView.transition(with: networkCallView, duration: 0.6,
                          options: .transitionCrossDissolve,
                          animations: {self.networkCallView.isHidden = false
                      })
        btnurlsession.backgroundColor = UIColor.gray
        btnAlamofire.backgroundColor = UIColor.gray
        btnAFNetworking.backgroundColor = UIColor.green
        reloadNetWorkCallView()
    }

    @IBAction func validateSpan(_ sender: Any) {

        var status = checkSpanData()
        if !status {
            // If it is failing check one more time
            status = checkSpanData()
        }

        self.lblSuccess.isHidden = !status
        self.lblFailed.isHidden = status

    }

    /* Validating span data collected by RUM SDK
        
      Returns: Bool
      returning the status of the span data validation.
        
     */
    func checkSpanData() -> Bool {
        self.btnClose.sendActions(for: .touchUpInside)
        var status: Bool!
        switch self.typeOfAPIMethod {
        case "POST":
            status = method_post_validation()
        case "GET":
            status = method_get_validation()
        case "DELETE":
            status = method_delete_validation()
        case "PUT":
            status = method_put_validation()
        default:
            print("No API Method Provided")
            return false
        }

        return status
    }

    /* Reloading the views for next event */
    func reloadNetWorkCallView() {
        btnPost.backgroundColor = UIColor.systemYellow
        btnGet.backgroundColor = UIColor.systemYellow
        btnDelete.backgroundColor = UIColor.systemYellow
        btnPut.backgroundColor = UIColor.systemYellow

        self.lblSuccess.isHidden = true
        self.lblFailed.isHidden = true
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    // swiftlint:disable cyclomatic_complexity
    @IBAction func deleteCall(_ sender: Any) {
        typeOfAPIMethod = "DELETE"
        if strCompare == "URLSession" {

            guard let url = URL(string: "https://my-json-server.typicode.com/typicode/demo/posts/1") else {
                        print("Error: cannot create URL")
                        return
                    }
                    // Create the request
                    var request = URLRequest(url: url)
                    request.httpMethod = "DELETE"
                    URLSession.shared.dataTask(with: request) { data, response, error in
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
                        } catch {
                            print("Error: Trying to convert JSON data to string")
                            return
                        }
                    }.resume()

        } else if strCompare == "Alamofire"{

            AF.request("https://my-json-server.typicode.com/typicode/demo/posts/1", method: .delete, parameters: nil, headers: nil).responseJSON { AFdata in
                switch AFdata.result {
                case .success(let result):
                    print(result)
                case .failure(let error):
                    print(error)
                }
            }

        } else if strCompare == "AFNetworking"{

            manager.delete("https://my-json-server.typicode.com/typicode/demo/posts/1", parameters: nil, headers: nil, success: { (_, _) -> Void in
               }, failure: nil)

        }
        btnPost.backgroundColor = UIColor.systemYellow
        btnGet.backgroundColor = UIColor.systemYellow
        btnDelete.backgroundColor = UIColor.green
        btnPut.backgroundColor = UIColor.systemYellow
    }

    @IBAction func postCall(_ sender: Any) {
        typeOfAPIMethod = "POST"

        if strCompare == "URLSession" {

            let Url = String(format: "https://reqres.in/api/login")
            guard let serviceUrl = URL(string: Url) else { return }

            let parameters: [String: Any] = ["email": "eve.holt@reqres.in", "password": "cityslicka"]
            var request = URLRequest(url: serviceUrl)
            request.httpMethod = "POST"
            request.setValue("Application/json", forHTTPHeaderField: "Content-Type")

            guard let httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {
                return
            }

            request.httpBody = httpBody
            request.timeoutInterval = 20

            let session = URLSession.shared
            session.dataTask(with: request) { (data, _, error) in
                if let data = data {
                    do {
                        _ = try JSONSerialization.jsonObject(with: data, options: [])
                        print("Post successfully")
                    } catch {
                        print(error)
                    }
                }
            }.resume()

        } else if strCompare == "Alamofire"{

            AF.request("https://reqres.in/api/login", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: nil).responseJSON { AFdata in
                switch AFdata.result {
                case .success(let result):
                    print(result)
                case .failure(let error):
                    print(error)
                }
            }

        } else if strCompare == "AFNetworking"{

            manager.post("https://reqres.in/api/login", parameters: parameters, headers: nil, progress: nil, success: { (_, _) -> Void in
            }, failure: nil)
        }

        btnPost.backgroundColor = UIColor.green
        btnGet.backgroundColor = UIColor.systemYellow
        btnDelete.backgroundColor = UIColor.systemYellow
        btnPut.backgroundColor = UIColor.systemYellow
    }

    @IBAction func getCall(_ sender: Any) {
        typeOfAPIMethod = "GET"

        if strCompare == "URLSession" {
            // URLSessiongetCall
            let url = URL(string: "https://www.splunk.com")!
            let task = URLSession.shared.dataTask(with: url) {(data, _, _) in
                guard data != nil else { return }
                print("Get successfully")
            }

            task.resume()

        } else if strCompare == "Alamofire"{

            let url = URL(string: "https://www.splunk.com")!
            AF.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: nil)
                    .responseJSON(completionHandler: { response in
                        switch response.result {
                        case .success(let result):
                            print(result)
                        case .failure(let error):
                            print(error)
                        }
                })

        } else if strCompare == "AFNetworking"{

                manager.get("https://www.splunk.com", parameters: nil, headers: nil, progress: nil, success: { (_, _) -> Void in
                    }, failure: nil)

        }

        btnPost.backgroundColor = UIColor.systemYellow
        btnGet.backgroundColor = UIColor.green
        btnDelete.backgroundColor = UIColor.systemYellow
        btnPut.backgroundColor = UIColor.systemYellow
    }

    @IBAction func putCall(_ sender: Any) {
        typeOfAPIMethod = "PUT"

        if strCompare == "URLSession" {

            guard let url = URL(string: "https://reqres.in/api/users/2") else {
                print("Error: cannot create URL")
                return
            }

            // Create model
            struct UploadData: Codable {
                let name: String
                let job: String
            }

            // Add data to the model
            let uploadDataModel = UploadData(name: "Nicole", job: "iOS Developer")

            // Convert model to JSON data
            guard let jsonData = try? JSONEncoder().encode(uploadDataModel) else {
                print("Error: Trying to convert model to JSON data")
                return
            }

            // Create the request
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            URLSession.shared.dataTask(with: request) { _, _, error in
                guard error == nil else {
                    print("Error: error calling PUT")
                    print(error!)
                    return
                }
            }.resume()

        } else if strCompare == "Alamofire"{

            AF.request("https://reqres.in/api/users/2", method: .put, parameters: params, headers: nil).responseJSON { AFdata in
                switch AFdata.result {
                case .success(let result):
                    print(result)
                case .failure(let error):
                    print(error)
                }
            }

        } else if strCompare == "AFNetworking"{

            manager.put("https://reqres.in/api/users/2", parameters: params, headers: nil, success: { (_, _) -> Void in
            }, failure: nil)

        }

        btnPost.backgroundColor = UIColor.systemYellow
        btnGet.backgroundColor = UIColor.systemYellow
        btnDelete.backgroundColor = UIColor.systemYellow
        btnPut.backgroundColor = UIColor.green
    }

    @IBAction func btnClose(_ sender: Any) {
        networkCallView.isHidden = true
        strCompare = ""
    }
}
