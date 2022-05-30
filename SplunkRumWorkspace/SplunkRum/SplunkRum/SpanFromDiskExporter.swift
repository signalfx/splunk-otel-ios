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

let MAX_CONTENT_LENGTH = 1024 * 512
let MAX_BANDWIDTH_KB_PER_SECOND = 2.0

class BandwidthTracker {
    let maxSamples: Int
    let timeWindowNanos: UInt64
    var samples: [(Int, UInt64)] = []
    
    init(timeWindowMillis: UInt64 = 10_000, maxSamples: Int = 60) {
        self.maxSamples = maxSamples
        self.timeWindowNanos = timeWindowMillis * 1_000_000
    }
    
    func add(bytes: Int, timeNanos: UInt64) {
        if samples.count >= maxSamples {
            samples.removeFirst()
        }
        
        samples.append((bytes, timeNanos))
    }
    
    /// Returns bandwidth in KiB/s
    func bandwidth(timeNanosNow: UInt64) -> Double {
        let samplesInWindow = samples.filter { (_, ts) in
            timeNanosNow >= ts && timeNanosNow - ts <= timeWindowNanos
        }
        
        if samplesInWindow.isEmpty {
            return 0.0
        }

        let transferredBytes = samplesInWindow.reduce(0, { total, sample in
            let (bytes, _) = sample
            return total + bytes
        })
        
        let dbgSamples = samplesInWindow.map { (b, ts) in
            (b, Double(timeNanosNow - ts) / 1e9)
        }
        
        let beginTime = timeNanosNow >= timeWindowNanos ? timeNanosNow - timeWindowNanos : 0
        let intervalSeconds = Double(timeNanosNow - beginTime) / 1e9
        print(dbgSamples)
        return Double(transferredBytes) / 1024.0 / intervalSeconds
    }
}

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
            print("bandwidth: \(bw)")
            if bw > MAX_BANDWIDTH_KB_PER_SECOND {
                loopDelayMs = 1_000
                print("Exceeding bandwidth!!!")
                return
            }
            
            let spans = spanDb.fetchLatest(count: 64)
            
            if spans.isEmpty {
                return
            }
            
            let payload = preparePayload(spans: spans, contentLengthLimit: MAX_CONTENT_LENGTH)
            let req = buildRequest(url: url, data: payload.content)
            
            print("payload size \(payload.content.count)")
            
            let sem = DispatchSemaphore(value: 0)
            
            var success = false
            let task = URLSession.shared.dataTask(with: req) { _, _, error in
                if error == nil {
                    success = true
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
            
            if success {
                _ = spanDb.erase(ids: payload.ids)
            }
        }
        
        DispatchQueue.global().async {
            processSpans()
        }
    }
}
