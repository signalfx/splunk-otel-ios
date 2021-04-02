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
import DeviceKit

func addPreSpanFields(span: ReadableSpan) {
    addUIFields(span: span)
}

func computeDeviceModel() -> String {
    // Using DeviceKit for this because the native apis for these things don't return
    // convenient identifiers like "iPhone6s"
    return Device.current.description
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

    let appName: String
    let appVersion: String?
    let deviceModel: String
    init() {
        let app = Bundle.main.infoDictionary?["CFBundleName"] as? String
        if app != nil {
            appName = app!
        } else {
            appName = "unknown-app"
        }
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        deviceModel = computeDeviceModel()
    }

    func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        span.setAttribute(key: "app", value: appName)
        if appVersion != nil {
            span.setAttribute(key: "app.verson", value: appVersion!)
        }
        span.setAttribute(key: "splunk.rumSessionId", value: getRumSessionId())
        span.setAttribute(key: "splunk.rumVersion", value: SplunkRumVersionString)
        span.setAttribute(key: "device.model", value: deviceModel)
        span.setAttribute(key: "os.version", value: UIDevice.current.systemVersion)
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
