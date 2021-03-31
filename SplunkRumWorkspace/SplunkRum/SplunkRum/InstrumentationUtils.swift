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
import UIKit
import OpenTelemetryApi
import OpenTelemetrySdk

private func addUIFields(span: ReadableSpan) {
    // FIXME threading - must be used from main thread; probably need to listen for changes and cache (currently works but produces warning messages)
    let wins = UIApplication.shared.windows
    if !wins.isEmpty {
        // windows are arranged in z-order, with topmost (e.g. popover) being the last in array
        let vc = wins[wins.count-1].rootViewController
        if vc != nil {
            span.setAttribute(key: "screen.name", value: String(describing: type(of: vc!)))
            // FIXME SwiftUI UIHostingController vc when cast has a "rootView" var which does
            // not appear to be accessible generically
        }
    }
    // FIXME others?
}

func addPreSpanFields(span: ReadableSpan) {
    addUIFields(span: span)
}

func computeSplunkRumVersion() -> String {
    let dict = Bundle(for: SplunkRum.self).infoDictionary
    return dict?["CFBundleShortVersionString"] as? String ?? "unknown"
}
let SplunkRumVersionString = computeSplunkRumVersion()

func buildTracer() -> Tracer {
    return OpenTelemetry.instance.tracerProvider.get(instrumentationName: "splunk-ios", instrumentationVersion: SplunkRumVersionString)
}

func nop() {
        // "default label in a switch should have at least one executable statement"
}

class GlobalAttributesProcessor: SpanProcessor {
    var isStartRequired = true

    var isEndRequired = false

    var appName: String
    var appVersion: String?
    init() {
        let app = Bundle.main.infoDictionary?["CFBundleName"] as? String
        if app != nil {
            appName = app!
        } else {
            appName = "unknown-app"
        }
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        span.setAttribute(key: "app", value: appName)
        if appVersion != nil {
            span.setAttribute(key: "app.verson", value: appVersion!)
        }
        span.setAttribute(key: "splunk.rumSessionId", value: getRumSessionId())
        span.setAttribute(key: "splunk.rumVersion", value: SplunkRumVersionString)
        globalAttributes.forEach({ (key: String, value: Any) in
            switch value {
            case is Int:
                span.setAttribute(key: key, value: value as! Int)
            case is String:
                span.setAttribute(key: key, value: value as! String)
            case is Double:
                span.setAttribute(key: key, value: value as! Double)
            case is Bool:
                span.setAttribute(key: key, value: value as! Bool)
            default:
                nop()
            }
        })
        addPreSpanFields(span: span)
    }

    func onEnd(span: ReadableSpan) { }
    func shutdown() { }
    func forceFlush() { }
}
