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
    // FIXME threading - SplunkRum initialization and AppStart can happen before UI is initialized
    // FIXME threading even worse - must be used from main thread; probably need to listen for changes and cache (currently works but produces warning messages)
    let wins = UIApplication.shared.windows
    if !wins.isEmpty {
        // windows are arranged in z-order, with topmost (e.g. popover) being the last in array
        let vc = wins[wins.count-1].rootViewController
        if vc != nil {
            // FIXME demangle swift names
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
