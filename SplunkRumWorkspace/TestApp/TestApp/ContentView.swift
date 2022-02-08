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
import OpenTelemetryApi
import OpenTelemetrySdk

// swiftlint:disable missing_docs
struct ContentView: View {
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
    func downloadRequest() {
        print("download!")
        let url = URL(string: "http://www.splunk.com")!
        var req = URLRequest(url: url)
        let task = URLSession.shared.downloadTask(with: url) {(_:URL?, _: URLResponse?, _) in
            print("download finished")
        }
        task.resume()
    }
    func hideKeyboard() {
        print("hideKeyboard")
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

    }

    func throwy() {
        NSException(name: NSExceptionName(rawValue: "IllegalFormatError"),
                    reason: "Could not parse input",
                    userInfo: nil).raise()
        print("should not reach here")
    }
    func throwyBackgroundThread() {
        DispatchQueue.global(qos: .background).async {
            NSException(name:
                            NSExceptionName(rawValue: "IllegalFormatError"),
                        reason: "Could not parse input",
                        userInfo: nil).raise()
        }
    }
    func hardCrash() {
        let null = UnsafePointer<UInt8>(bitPattern: 0)
        let derefNull = null!.pointee
    }
    func manualSpan() {
        let span = OpenTelemetrySDK.instance.tracerProvider
            .get(instrumentationName: "manual")
            .spanBuilder(spanName: "manualSpan")
            .startSpan()
        span.setAttribute(key: "manualKey", value: "manualValue")
        span.end()

    }
    func callAsynchronousRequestConnection() {
        print("NSURLConnection - Asynchronous Call")
        let url = URL(string: "https://mock.codes/200")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET" // "GET" // "HEAD"
        NSURLConnection.sendAsynchronousRequest(req, queue: OperationQueue.main) {(_, data, _) in
            guard let data = data else { return }
            print("got some data")
            print(data)
        }
   }
  func callSynchronousRequestConnection() {
        print("NSURLConnection - Synchronous Call")
        let url = URL(string: "https://mock.codes/500")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET" // "GET" // "HEAD"
        var response: URLResponse? = URLResponse()
        do {
            let urlData = try NSURLConnection.sendSynchronousRequest(req, returning: &response)
        } catch {
            print(error)
        }
   }
    @State var text = ""
    @State var toggle = true
    @State var isShowingModal = false

    var body: some View {
        VStack {
            Button {
                self.throwy()
            } label: {
                Text("Throw!")
            }
            Button {
                self.throwyBackgroundThread()
            } label: {
                Text("Throw (bg)!")
            }
            Button {
                self.hardCrash()
            } label: {
                Text("Hard crash")
            }
            Button {
                self.networkRequest()
            } label: {
                Text("Network (req)!")
            }
            Button {
                self.downloadRequest()
            } label: {
                Text("Download")
            }
            Button {
                self.manualSpan()
            } label: {
                Text("Manual Span")
            }
            Button {
                self.callAsynchronousRequestConnection()
            } label: {
                Text("Connection-Asynchronous")
            }
            Button {
                self.callSynchronousRequestConnection()
            } label: {
                Text("Connection-Synchronous")
            }

        }
        HStack {
            TextField("Text", text: $text)
                .padding()
                .keyboardType(.numberPad)
            Button(action: self.hideKeyboard, label: {
                Text("OK")
            })
        }
        HStack {
            Toggle(isOn: $toggle) {
                Text("Toggle")
            }
            // Perhaps add a button to dismiss it
            Button("Modal") {
                isShowingModal.toggle()
            }.sheet(isPresented: $isShowingModal, content: {
                VStack {
                    Text("MODAL SHEET")
                    Text("PLEASE IGNORE")
                    Button("Dismiss") {
                        isShowingModal.toggle()
                    }
                }
            })
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
