//
/*
Copyright 2022 Splunk Inc.

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

let MAX_CONTENT_LENGTH = 1024 * 512
let MAX_BANDWIDTH_KB_PER_SECOND = 15.0

fileprivate struct Payload {
    let content: Data
    let ids: [Int64]
}

fileprivate func preparePayload(spans: [(Int64, String)], contentLengthLimit: Int) -> Payload {
    var ids: [Int64] = []
    var payloadSpans: [String] = []
    var contentLength = 0

    for (id, spanJson) in spans {
        let length = spanJson.utf8.count + 1 // Include the comma separator
        if contentLength + length <= MAX_CONTENT_LENGTH {
            ids.append(id)
            payloadSpans.append(spanJson)
            contentLength += length
        }
    }

    let content = Data("[\(payloadSpans.joined(separator: ","))]".utf8)
    return Payload(content: content, ids: ids)
}

fileprivate func shouldEraseSpans(_ response: URLResponse?) -> Bool {
    if response == nil {
        return true
    }

    let resp = response as? HTTPURLResponse

    if resp == nil {
        return true
    }

    switch resp!.statusCode {
    case 200...399:
        return true
    case 400, // bad request
         406, // not acceptable
         413, // payload too large
         422: // unprocessable entity
        return true
    default:
        return false
    }
}

fileprivate func buildRequest(url: URL, data: Data) -> URLRequest {
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = data
    return req
}

class SpanFromDiskExport {
    static func start(spanDb: SpanDb, endpoint: String) {
        guard let url = URL(string: endpoint) else {
            print("Malformed endpoint URL: \(endpoint)")
            return
        }

        let bandwidthTracker = BandwidthTracker()

        var processSpans: (() -> Void)!
        processSpans = {
            var loopDelayMs: Int = 5_000
            var bytesSent: Int = 0

            defer {
                bandwidthTracker.add(bytes: bytesSent, timeNanos: DispatchTime.now().rawValue)
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(loopDelayMs), execute: {
                    processSpans()
                })
            }

            let bw = bandwidthTracker.bandwidth(timeNanosNow: DispatchTime.now().rawValue)
            if bw > MAX_BANDWIDTH_KB_PER_SECOND {
                loopDelayMs = 1_000
                return
            }

            let spans = spanDb.fetchLatest(count: 64)

            if spans.isEmpty {
                return
            }

            let payload = preparePayload(spans: spans, contentLengthLimit: MAX_CONTENT_LENGTH)
            let req = buildRequest(url: url, data: payload.content)

            let sem = DispatchSemaphore(value: 0)

            var shouldErase = false
            let task = URLSession.shared.dataTask(with: req) { _, resp, error in
                // Error might even be nil when the error code clearly is not
                if error == nil && shouldEraseSpans(resp) {
                    shouldErase = true
                    // In case of a successful upload, go for another round.
                    // We are limited by bandwidth anyway, this provides an upload burst.
                    loopDelayMs = 50
                } else {
                    debug_log("Failed to upload spans: \(error.debugDescription)")
                }
                bytesSent = payload.content.count
                sem.signal()
            }
            task.resume()
            sem.wait()

            if shouldErase {
                _ = spanDb.erase(ids: payload.ids)
            }
        }

        DispatchQueue.global().async {
            processSpans()
        }
    }
}
