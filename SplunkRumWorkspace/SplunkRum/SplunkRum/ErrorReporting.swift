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

// FIXME add component= to all spans?
func reportExceptionErrorSpan(e: NSException) {
    let tracer = buildTracer()
    let now = Date()
    let span = tracer.spanBuilder(spanName: "SplunkRum.reportError").setStartTime(time: now).startSpan()
    span.setAttribute(key: "error", value: true)
    span.setAttribute(key: "error.name", value: e.name.rawValue)
    if e.reason != nil {
        span.setAttribute(key: "error.message", value: e.reason!)
    }
    let stack = e.callStackSymbols.joined(separator: "\n")
    if !stack.isEmpty {
        span.setAttribute(key: "error.stack", value: stack)
    }
    span.end(time: now)
}

func reportErrorErrorSpan(e: Error) {
    let tracer = buildTracer()
    let now = Date()
    let span = tracer.spanBuilder(spanName: "SplunkRum.reportError").setStartTime(time: now).startSpan()
    span.setAttribute(key: "error", value: true)
    span.setAttribute(key: "error.name", value: String(describing: type(of: e)))
    span.setAttribute(key: "error.message", value: e.localizedDescription)
    span.end(time: now)
}

func reportStringErrorSpan(e: String) {
    let tracer = buildTracer()
    let now = Date()
    let span = tracer.spanBuilder(spanName: "SplunkRum.reportError").setStartTime(time: now).startSpan()
    span.setAttribute(key: "error", value: true)
    span.setAttribute(key: "error.name", value: "String")
    span.setAttribute(key: "error.message", value: e)
    span.end(time: now)
}
