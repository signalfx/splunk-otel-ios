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

import SwiftUI

class MySessionDelegate: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate, URLSessionStreamDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("delegate splunk.rumSessionId")
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("delegate didFinishEventsForBackground")
    }
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("delegate didBecomeInvalidWithError")
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("delegate task didCompleteWithError")
    }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("delegate didReceive challenge")
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("delegate didReceive data")
    }
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        print("delegate taskIsWaitingForConnectivity")
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        print("delegate didSendBodyData")
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        print("delegate did receive headers")
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        print("delegate didFinishCollecting metrics")
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("delegate didReceive challenge (2)")
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
        print("delegate didBecome stream")
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        print("delegate didBecome download")
    }
    func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask) {
        print("delegate readClosed")
    }
    func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask) {
        print("delegate writeClosed")
    }
    func urlSession(_ session: URLSession, streamTask: URLSessionStreamTask, didBecome inputStream: InputStream, outputStream: OutputStream) {
        print("delegate didBecome i/o")
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        print("delegate didResumeAtOffset")
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        print("delegate needNewBodyStream")
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        print("delegate downloadtask didwriteData")
    }
    func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {
        print("delegate betterRouteDiscoveredFor")
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        print("delegate willCacheResponse")
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
        print("delegate willBeginDelayedRequest")
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        print("delegate willPerformHTTPRedirection")
    }
}

struct ContentView: View {
    let delegate: URLSessionDelegate? = MySessionDelegate()
    func networkRequest() {
        print("network (req)!")
        let url = URL(string: "http://127.0.0.1:7878/data")!
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        let task = URLSession.shared.dataTask(with: req) {(data, _: URLResponse?, _) in
            guard let data = data else { return }
            print("got some data")
            print(data)

        }
        task.resume()
    }
    func network() {
        print("network!")
        let url = URL(string: "http://127.0.0.1:7878/data")!
        let task = URLSession.shared.dataTask(with: url) {(data, _: URLResponse?, _) in
            guard let data = data else { return }
            print("got some data")
            print(data)

        }
        task.resume()
    }
    func throwy() {
        NSException(name: NSExceptionName(rawValue: "IllegalFormatError"), reason: "Could not parse input", userInfo: nil).raise()
        print("should not reach here")
    }
    func networkDelegate() {
        let sess = URLSession(configuration: URLSessionConfiguration.default, delegate: delegate, delegateQueue: nil)
        let task = sess.dataTask(with: URL(string: "http://127.0.0.1:7878/data")!) {(data, _: URLResponse?, _) in
            guard let data = data else { return }
            print("got some data")
            print(data)

        }
        task.resume()
    }
    func upload() {
        print("upload")
        let data = "this is my POST data".data(using: .utf8)!
        var req = URLRequest(url: URL(string: "http://127.0.0.1:7878/data")!)
        req.httpMethod = "POST"
        URLSession.shared.uploadTask(with: req, from: data).resume()
    }

    var body: some View {
        Button(action: {
            self.network()
        }) {
            Text("Network (url)!")
        }
        Text("")
            .padding()
        Button(action: {
            self.throwy()
        }) {
            Text("Throw!")
        }
        Text("")
            .padding()
        Button(action: {
            self.networkRequest()
        }) {
            Text("Network (req)!")
        }
        Text("")
            .padding()
        Button(action: {
            self.networkDelegate()
        }) {
            Text("Network (delegate)!")
        }
        Text("")
            .padding()
        Button(action: {
            self.upload()
        }) {
            Text("upload!")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
