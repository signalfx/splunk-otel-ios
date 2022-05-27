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

    init(proxy: SpanExporter) {
        self.proxy = proxy
    }

  func export(spans: [SpanData]) -> SpanExporterResultCode {
        let result = proxy.export(spans: spans)  // call zipkinexporter
        if result == .failure {
           CoreDataManager.shared.insertSpanValue(spans) // seperate values
            return .failure
        }
        return .success
    }

    func flush() -> SpanExporterResultCode {
        return proxy.flush()
    }

    func shutdown() {
        proxy.shutdown()
    }

    // MARK: - attempt to export from DB
    func attemptDBExport() -> SpanExporterResultCode {
        // way 1 - delete span if size is exceeded.
        CoreDataManager.shared.flushDbIfSizeExceed()
                // OR
        // way 2 -delete spans from db FLUSH FIFO or 4 h time logic.
      // CoreDataManager.shared.flushOutSpanAfterTimePeriod()

        let dbspans = CoreDataManager.shared.fetchSpanValues()

        if dbspans.isEmpty {
            return .success
        } else {
            // delete exported span only
            CoreDataManager.shared.deleteSpanData(spans: dbspans)
            return .success
        }
    }
}
