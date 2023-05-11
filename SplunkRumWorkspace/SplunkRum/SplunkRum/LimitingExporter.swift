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

// Performs several kinds of limiting:
// - attribute value length limiting
// - rate limiting by component type
// - span rejection based on setRejectionFilter

class LimitingExporter: SpanExporter {
    let MAX_ATTRIBUTE_LENGTH = 4096
    static let SPAN_RATE_LIMIT_PERIOD = 30 // seconds
    let MAX_SPANS_PER_PERIOD_PER_COMPONENT = 100

    let proxy: SpanExporter
    var component2counts: [String: Int] = [:]
    var nextRateLimitReset = Date().addingTimeInterval(TimeInterval(LimitingExporter.SPAN_RATE_LIMIT_PERIOD))
    let spanFilter: ((SpanData) -> SpanData?)?

    init(proxy: SpanExporter, spanFilter: ((SpanData) -> SpanData?)?) {
        self.proxy = proxy
        self.spanFilter = spanFilter
    }

    // Returns true if span should be dropped
    func rateLimit(_ span: SpanData) -> Bool {
        let component = span.attributes[Constants.AttributeNames.COMPONENT]?.description ?? "unknown"
        var count = component2counts[component] ?? 0
        count += 1
        component2counts[component] = count
        return count > MAX_SPANS_PER_PERIOD_PER_COMPONENT
    }

    // Returns true if span should be rejected
    func filter(_ span: SpanData) -> SpanData? {
        if spanFilter != nil {
            return spanFilter!(span)
        }
        return span
    }

    func limit(_ spans: [SpanData]) -> [SpanData] {
        // FIXME performance mess of this
        var result: [SpanData] = []
        spans.forEach { span in
            if !rateLimit(span) {
                var toAdd = filter(span)
                if toAdd != nil {
                    let newAttrs = toAdd!.attributes.mapValues { val -> AttributeValue in
                        let str = val.description
                        if str.count > MAX_ATTRIBUTE_LENGTH {
                            return .string(String(str.prefix(MAX_ATTRIBUTE_LENGTH)))
                        }
                        return val
                    }
                    toAdd!.settingAttributes(newAttrs)
                    result.append(toAdd!)
                }
            }
        }
        return result
    }

    func possiblyResetRateLimits(_ now: Date) {
        if now.compare(nextRateLimitReset) == ComparisonResult.orderedDescending {
            resetRateLimits()
        }
    }
    func resetRateLimits() {
        component2counts.removeAll()
        nextRateLimitReset = Date().addingTimeInterval(TimeInterval(LimitingExporter.SPAN_RATE_LIMIT_PERIOD))
    }

    func export(spans: [SpanData]) -> SpanExporterResultCode {
        possiblyResetRateLimits(Date())
        return proxy.export(spans: limit(spans))
    }

    func flush() -> SpanExporterResultCode {
        proxy.flush()
    }

    func shutdown() {
        proxy.shutdown()
    }

}
