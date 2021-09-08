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
import UIKit
import OpenTelemetrySdk

func initializeAppLifecycleInstrumentation() {
    /*
     Observed event sequences:

     Send to background (i.e., push home button):
     UIApplicationWillResignActiveNotification
     UIApplicationSuspendedEventsOnlyNotification
     UIApplicationDidEnterBackgroundNotification
     
     Bring back to foreground:
     UIApplicationWillEnterForegroundNotification
     UIApplicationDidBecomeActiveNotification
     
     Dismiss (kill from app switcher)
     UIApplicationWillResignActiveNotification
     UIApplicationSuspendedNotification
     UIApplicationDidEnterBackgroundNotification
     UIApplicationWillTerminateNotification (only if app was foreground)
     */
    let events = [
        "UIApplicationWillResignActiveNotification",
        "UIApplicationSuspendedEventsOnlyNotification",
        "UIApplicationDidEnterBackgroundNotification",
        "UIApplicationWillEnterForegroundNotification",
        "UIApplicationDidBecomeActiveNotification",
        "UIApplicationSuspendedNotification",
        "UIApplicationWillTerminateNotification"
    ]

    for event in events {
        _ = NotificationCenter.default.addObserver(forName: NSNotification.Name(event), object: nil, queue: nil) { (_) in
            lifecycleEvent(event)
        }
    }

}
var activeSpan: SpanHolder?
func lifecycleEvent(_ event: String) {
    // these two start spans
    if event == "UIApplicationWillResignActiveNotification" ||
            event == "UIApplicationWillEnterForegroundNotification" {
        if activeSpan == nil {
            let span = buildTracer().spanBuilder(spanName: event == "UIApplicationWillResignActiveNotification" ? "ResignActive" : "EnterForeground").startSpan()
            span.setAttribute(key: "component", value: "app-lifecycle")
            activeSpan = SpanHolder(span)
        }
    }

    // all events get added to the active span, if any
    if activeSpan != nil {
        activeSpan!.span.addEvent(name: event)
    }

    // these two end spans
    if event == "UIApplicationDidBecomeActiveNotification" ||
            event == "UIApplicationDidEnterBackgroundNotification" {
        activeSpan?.span.end()
        activeSpan = nil
    }

    // this one gets its own special span
    if event == "UIApplicationWillTerminateNotification" {
        let now = Date()
        let span = buildTracer().spanBuilder(spanName: "AppTerminating").setStartTime(time: now).startSpan()
        span.setAttribute(key: "component", value: "AppLifecycle")
        span.end(time: now)
    }

    // these two attempt to send to the beacon
    if event == "UIApplicationWillTerminateNotification" ||
            event == "UIApplicationDidEnterBackgroundNotification" {
        OpenTelemetrySDK.instance.tracerProvider.forceFlush()

    }
}
