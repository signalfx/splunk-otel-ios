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
import OpenTelemetrySdk
import OpenTelemetryApi

// Performs two kinds of limiting:
// - attribute value length limiting
// - rate limiting by component type (FIXME unimplemented as yet)

class LimitingExporter: SpanExporter {
    let MAX_ATTRIBUTE_LENGTH = 4096
    let SPAN_RATE_LIMIT_PERIOD = 30 // seconds
    let MAX_SPANS_PER_PERIOD_PER_COMPONENT = 100

    var proxy: SpanExporter

    init(proxy: SpanExporter) {
        self.proxy = proxy
    }

    func limit(_ spans: [SpanData]) -> [SpanData] {
        // FIXME performance mess of this
        var result: [SpanData] = []
        spans.forEach { span in
            var toAdd = span
            let newAttrs = span.attributes.mapValues { val -> AttributeValue in
                let str = val.description
                if str.count > MAX_ATTRIBUTE_LENGTH {
                    return .string(String(str.prefix(MAX_ATTRIBUTE_LENGTH)))
                }
                return val
            }
            toAdd.settingAttributes(newAttrs)
            result.append(toAdd)
        }
        return result
    }

    func export(spans: [SpanData]) -> SpanExporterResultCode {
        return proxy.export(spans: limit(spans))
    }

    func flush() -> SpanExporterResultCode {
        proxy.flush()
    }

    func shutdown() {
        proxy.shutdown()
    }

}
