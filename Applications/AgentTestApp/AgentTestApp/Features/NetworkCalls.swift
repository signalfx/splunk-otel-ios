//
/*
Copyright 2025 Splunk Inc.

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

class SessionDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {

    // MARK: - Public

    let semaphore = DispatchSemaphore(value: 0)


    // MARK: - URLSessionTaskDelegate methods

    func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError _: Error?) {
        semaphore.signal()
    }
}


class NetworkCalls {

    // MARK: - Simple network calls

    func simpleNetworkCallWith(targetURL: String) {
        guard let url = URL(string: targetURL) else {
            return
        }

        let request = URLRequest(url: url)
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data,
                let string = String(bytes: data, encoding: .utf8)
            {
                print(string)
            }
            semaphore.signal()
        }
        task.resume()

        semaphore.wait()
    }

    func simpleNetworkCallWithDelegate(targetURL: String) {

        guard let url = URL(string: targetURL) else {
            return
        }

        let request = URLRequest(url: url)

        let delegate = SessionDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        let task = session.dataTask(with: request)
        task.resume()

        delegate.semaphore.wait()
    }
}
