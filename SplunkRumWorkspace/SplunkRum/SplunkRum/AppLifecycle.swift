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

let INACTIVITY_SESSION_TIMEOUT_SECONDS = 15 * 60
private var sessionIdInactivityExpiration = Date().addingTimeInterval(TimeInterval(INACTIVITY_SESSION_TIMEOUT_SECONDS))

// Constants for lifecyle events that are being observed
private let UI_APPLICATION_WILL_RESIGN_ACTIVE_NOTIFICATION = "UIApplicationWillResignActiveNotification"
private let UI_APPLICATION_SUSPENDED_EVENTS_ONLY_NOTIFICATION = "UIApplicationSuspendedEventsOnlyNotification"
private let UI_APPLICATION_DID_ENTER_BACKGROUND_NOTIFICATION = "UIApplicationDidEnterBackgroundNotification"
private let UI_APPLICATION_WILL_ENTER_FOREGROUND_NOTIFICATION = "UIApplicationWillEnterForegroundNotification"
private let UI_APPLICATION_DID_BECOME_ACTIVE_ACTIVE_NOTIFICATION = "UIApplicationDidBecomeActiveNotification"
private let UI_APPLICATION_SUSPENDED_NOTIFICATION = "UIApplicationSuspendedNotification"
private let UI_APPLICATION_WILL_TERMINATE_NOTIFICATION = "UIApplicationWillTerminateNotification"

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
        UI_APPLICATION_WILL_RESIGN_ACTIVE_NOTIFICATION,
        UI_APPLICATION_SUSPENDED_EVENTS_ONLY_NOTIFICATION,
        UI_APPLICATION_DID_ENTER_BACKGROUND_NOTIFICATION,
        UI_APPLICATION_WILL_ENTER_FOREGROUND_NOTIFICATION,
        UI_APPLICATION_DID_BECOME_ACTIVE_ACTIVE_NOTIFICATION,
        UI_APPLICATION_SUSPENDED_NOTIFICATION,
        UI_APPLICATION_WILL_TERMINATE_NOTIFICATION
    ]

    for event in events {
        _ = NotificationCenter.default.addObserver(forName: NSNotification.Name(event), object: nil, queue: nil) { (_) in
            lifecycleEvent(event)
        }
    }

}
var activeSpan: SpanHolder?
func lifecycleEvent(_ event: String) {
    invalidateSession(event)
    // these two start spans
    if event == UI_APPLICATION_WILL_RESIGN_ACTIVE_NOTIFICATION ||
            event == UI_APPLICATION_WILL_ENTER_FOREGROUND_NOTIFICATION {
        if activeSpan == nil {
            let span = buildTracer().spanBuilder(spanName: event == UI_APPLICATION_WILL_RESIGN_ACTIVE_NOTIFICATION ? Constants.SpanNames.RESIGNACTIVE : Constants.SpanNames.ENTER_FOREGROUND).startSpan()
            span.setAttribute(key: Constants.AttributeNames.COMPONENT, value: "app-lifecycle")
            activeSpan = SpanHolder(span)
        }
    }

    // all events get added to the active span, if any
    if activeSpan != nil {
        activeSpan!.span.addEvent(name: event)
    }

    // these two end spans
    if event == UI_APPLICATION_DID_BECOME_ACTIVE_ACTIVE_NOTIFICATION ||
            event == UI_APPLICATION_DID_ENTER_BACKGROUND_NOTIFICATION {
        activeSpan?.span.end()
        activeSpan = nil
    }

    // this one gets its own special span
    if event == UI_APPLICATION_WILL_TERMINATE_NOTIFICATION {
        let now = Date()
        let span = buildTracer().spanBuilder(spanName: Constants.SpanNames.APP_TERMINATING).setStartTime(time: now).startSpan()
        span.setAttribute(key: Constants.AttributeNames.COMPONENT, value: "AppLifecycle")
        span.end(time: now)
    }

    // these two attempt to send to the beacon
    if event == UI_APPLICATION_WILL_TERMINATE_NOTIFICATION ||
            event == UI_APPLICATION_DID_ENTER_BACKGROUND_NOTIFICATION {
        DispatchQueue.global(qos: .background).async {
            (OpenTelemetry.instance.tracerProvider as! TracerProviderSdk).forceFlush(timeout: 2)
        }

    }
}

func invalidateSession(_ event: String) {
    // 15 min inactivity then session time out
    if event == UI_APPLICATION_WILL_RESIGN_ACTIVE_NOTIFICATION {
        sessionIdInactivityExpiration = Date().addingTimeInterval(TimeInterval(INACTIVITY_SESSION_TIMEOUT_SECONDS))
    } else if event == UI_APPLICATION_WILL_ENTER_FOREGROUND_NOTIFICATION {
        if Date() > sessionIdInactivityExpiration { // expire 15 min
            _  = getRumSessionId(forceNewSessionId: true)
        }
    }
}
