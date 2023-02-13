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

class RetryExporter: SpanExporter {
    let MAX_PENDING_SPANS = 100

    let proxy: SpanExporter
    var pending: [SpanData] = []

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
        return .success
    }

    func flush() -> SpanExporterResultCode {
        _ = attemptPendingExport()
        return proxy.flush()
    }

    func shutdown() {
        proxy.shutdown()
    }
}
