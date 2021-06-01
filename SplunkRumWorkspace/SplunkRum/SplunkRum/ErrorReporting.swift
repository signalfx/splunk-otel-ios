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

func reportExceptionErrorSpan(e: NSException) {
    let tracer = buildTracer()
    let now = Date()
    let typeName = e.name.rawValue
    let span = tracer.spanBuilder(spanName: typeName).setStartTime(time: now).startSpan()
    span.setAttribute(key: "component", value: "error")
    span.setAttribute(key: "error", value: true)
    span.setAttribute(key: "exception.type", value: typeName)
    if e.reason != nil {
        span.setAttribute(key: "exception.message", value: e.reason!)
    }
    let stack = e.callStackSymbols.joined(separator: "\n")
    if !stack.isEmpty {
        span.setAttribute(key: "exception.stacktrace", value: stack)
    }
    span.end(time: now)
}

func reportErrorErrorSpan(e: Error) {
    let tracer = buildTracer()
    let now = Date()
    let typeName = String(describing: type(of: e))
    let span = tracer.spanBuilder(spanName: typeName).setStartTime(time: now).startSpan()
    span.setAttribute(key: "component", value: "error")
    span.setAttribute(key: "error", value: true)
    span.setAttribute(key: "exception.type", value: typeName)
    span.setAttribute(key: "exception.message", value: e.localizedDescription)
    span.end(time: now)
}

func reportStringErrorSpan(e: String) {
    let tracer = buildTracer()
    let now = Date()
    let typeName = "SplunkRum.reportError(String)"
    let span = tracer.spanBuilder(spanName: typeName).setStartTime(time: now).startSpan()
    span.setAttribute(key: "component", value: "error")
    span.setAttribute(key: "error", value: true)
    span.setAttribute(key: "exception.type", value: "String")
    span.setAttribute(key: "exception.message", value: e)
    span.end(time: now)
}
