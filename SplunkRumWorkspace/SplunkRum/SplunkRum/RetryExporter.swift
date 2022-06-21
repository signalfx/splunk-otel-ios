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
import OpenTelemetryApi
import OpenTelemetrySdk


class RetryExporter: SpanExporter {
    let MAX_PENDING_SPANS = 100

    let proxy: SpanExporter
    var pending: [SpanData] = []
    //var exportedSpans: [SpanData] = []

    init(proxy: SpanExporter) {
        self.proxy = proxy
    }

    func attemptPendingExport() -> SpanExporterResultCode {
        if pending.isEmpty {
            return .success
        }
        let result = proxy.export(spans: pending)
        if result == .success {
            pending.removeAll(keepingCapacity: true)
        }
        return result
    }

    func addToPending(_ spans: [SpanData]) {
        pending.append(contentsOf: spans)
        if pending.count > MAX_PENDING_SPANS {
            pending.removeFirst(pending.count - MAX_PENDING_SPANS)
        }
    }

    func export(spans: [SpanData]) -> SpanExporterResultCode {
        var result = attemptPendingExport()
        if result == .failure {
            addToPending(spans)
            return .failure
        }
        result = proxy.export(spans: spans)
        if result == .failure {
            addToPending(spans)
            return .failure
        }
       // exportedSpans.append(contentsOf: spans)
        for span in spans {
            getContentOfRecentTraceSegment(with:String(describing: span.traceId.hexString),name: span.name)
        }
        return .success
    }

    func flush() -> SpanExporterResultCode {
        _ = attemptPendingExport()
       // exportedSpans.removeAll()
        return proxy.flush()
    }

    func shutdown() {
        proxy.shutdown()
    }
    
    func getContentOfRecentTraceSegment(with traceID:String,name:String){
      //  let str2 = "https://api.us0.signalfx.com/v2/apm/trace/d1a8f3e2d7d3700c/latest" //get content of recent trace segment
        let str = "https://api.us0.signalfx.com/v1/apm/trace/" + traceID + "/latest"
        let url = URL(string: str)!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if sessiontoken == "" {
            return
        }
        request.addValue("X-SF-Token", forHTTPHeaderField:sessiontoken)
        
       // let sem = DispatchSemaphore(value: 0)

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
                print("Error: HTTP request failed for \(name)")
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
        }
        task.resume()
       // sem.wait()
        
    }
}
