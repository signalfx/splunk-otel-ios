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

import CiscoLogger
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import ResourceExtension
import SignPostIntegration
@_spi(SplunkInternal) import SplunkCommon
/*
func isUsefulString(_ s: String?) -> Bool {
    return s != nil && !s!.isEmpty
}

func computeDeviceModel() -> String {
    // Using DeviceKit for this because the native apis for these things don't return
    return "" // Device.current.description
}

class GlobalAttributesProcessor: SpanProcessor {
    func shutdown(explicitTimeout: TimeInterval?) {

    }
    
    var isStartRequired = true

    var isEndRequired = false

    let appName: String
    let appVersion: String?
    let deviceModel: String
    init(appName: String? = nil) {
        let app = Bundle.main.infoDictionary?["CFBundleName"] as? String
        if let name = appName {
            self.appName = name
        } else if let app = app {
            self.appName = app
        } else {
            self.appName = "unknown-app"
        }
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        let bundleShortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        appVersion = bundleShortVersion ?? bundleVersion
        deviceModel = computeDeviceModel()
    }

    func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        span.setAttribute(key: "app", value: appName)
        if appVersion != nil {
            span.setAttribute(key: "app.version", value: appVersion!)
        }
        span.setAttribute(key: "os.name", value: "iOS")
        span.setAttribute(key: "device.model.name", value: deviceModel)
        if Thread.current.isMainThread {
            span.setAttribute(key: "thread.name", value: "main")
        } else if isUsefulString(Thread.current.name) {
            span.setAttribute(key: "thread.name", value: Thread.current.name!)
        }
    }

    func onEnd(span: ReadableSpan) { }
    func shutdown() { }
    func forceFlush() { }
    func forceFlush(timeout: TimeInterval?) { }
}
*/
