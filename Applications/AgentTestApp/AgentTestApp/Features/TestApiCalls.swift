//
/*
Copyright 2024 Splunk Inc.

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

class TestApiCalls {
    
    func simpleGetWith(targetURL: String) {
        
        guard let url = URL(string: targetURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let semaphore = DispatchSemaphore(value: 0)

        print("GET Network Call to \(targetURL)")
        
        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data {
                let string = String(decoding: data, as: UTF8.self)
                print(string)
            }
            semaphore.signal()
        }
        task.resume()

        semaphore.wait()
    }

    func simplePutWith(targetURL: String, body: Data) {
        
        guard let url = URL(string: targetURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let semaphore = DispatchSemaphore(value: 0)

        print("PUT Network Call to \(targetURL)")

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data {
                let string = String(decoding: data, as: UTF8.self)
                print(string)
            }
            semaphore.signal()
        }
        task.resume()

        semaphore.wait()
    }

    func simplePostWith(targetURL: String, body: Data) {
        
        guard let url = URL(string: targetURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let semaphore = DispatchSemaphore(value: 0)

        print("POST Network Call to \(targetURL)")

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data {
                let string = String(decoding: data, as: UTF8.self)
                print(string)
            }
            semaphore.signal()
        }
        task.resume()

        semaphore.wait()
    }

    
    
}
