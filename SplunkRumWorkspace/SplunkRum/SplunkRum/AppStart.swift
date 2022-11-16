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
import OpenTelemetryApi

private func processStartTime() throws -> Date {
    let name = "kern.proc.pid"
    var len: size_t = 4
    var mib = [Int32](repeating: 0, count: 4)
    var kp: kinfo_proc = kinfo_proc()
    try mib.withUnsafeMutableBufferPointer { (mibBP: inout UnsafeMutableBufferPointer<Int32>) throws in
        try name.withCString { (nbp: UnsafePointer<Int8>) throws in
            guard sysctlnametomib(nbp, mibBP.baseAddress, &len) == 0 else {
                throw POSIXError(.EAGAIN)
            }
        }
        mibBP[3] = getpid()
        len =  MemoryLayout<kinfo_proc>.size
        guard sysctl(mibBP.baseAddress, 4, &kp, &len, nil, 0) == 0 else {
            throw POSIXError(.EAGAIN)
        }
    }
    // Type casts to finally produce the answer
    let startTime = kp.kp_proc.p_un.__p_starttime
    let ti: TimeInterval = Double(startTime.tv_sec) + (Double(startTime.tv_usec) / 1e6)
    return Date(timeIntervalSince1970: ti)
}

var spanStart = splunkLibraryLoadTime
var appStart: Span?

/*
 This blog post https://eisel.me/startup explains how we can check the ProcessInfo's `ActivePrewarm` environment flag to know if the application launch
 sequence was initiated due to prewarming. We track that scenario with `isPrewarm`.
 
 This also noted here on this discussion regarding iOS startup timing:
 https://github.com/MobileNativeFoundation/discussions/discussions/146
 */
var isPrewarm: Bool = false
/*
 According to https://developer.apple.com/documentation/uikit/app_and_environment/responding_to_the_launch_of_your_app/about_the_app_launch_sequence/ :
 "In iOS 15 and later, the system may, depending on device conditions,
 prewarm your app — launch nonrunning application processes to reduce the amount of time the user waits before the app is usable."
 */
var prewarmAvailable: Bool {
    if #available(iOS 15.0, *) {
        return true
    }
    return false
}

// Abitrary time interval (10 mins) chosen as a threshold for totally invalid calculations
var possibleAppStartTimingErrorThreshold: TimeInterval = 60 * 10

/*
 Used to track whether the application came into the foreground during startup from a background state.
 There are many reason's why an application's launch sequence might be initiated and the app not be brought to the foreground.
 One example might be a user notification response that can be handled in the background. This action triggers both
 didFinishLaunchingNotification and didBecomeVisibleNotification. In a normal user initiated start, the application state when the
 application is brought to the foreground is `inActive`. But in the notification response case, it will be `background`.
 We can set this flag to do additional calculation adjustments.
*/
var wasBackgroundedBeforeWillEnterForeground: Bool = false

func initializeAppStartupListeners() {
    let notifCenter = NotificationCenter.default
    // didBecomeActive
    var didBecomeActiveNotificationToken: NSObjectProtocol?
    let didBecomeActiveClosure: (Notification) -> Void = { notification in
        defer {
            if let didBecomeActiveNotificationToken = didBecomeActiveNotificationToken {
                notifCenter.removeObserver(didBecomeActiveNotificationToken)
            }
        }
        if isPrewarm && prewarmAvailable {
            // TODO: if we have a prewarm of true, either toss it or use the startup time from the lib
        }
        if (Date().timeIntervalSince1970 - (spanStart.timeIntervalSince1970)) > possibleAppStartTimingErrorThreshold {
            // TODO: if our calculation is still massive (some chosen threshold), ignore it
        }
        if wasBackgroundedBeforeWillEnterForeground {
            // TODO: if the didFinishLaunching notification came from a background state, the app was previously backgrounded.
        }
        if appStart != nil {
            appStart!.addEvent(name: notification.name.rawValue)
            appStart!.end()
            OpenTelemetry.instance.contextProvider.removeContextForSpan(appStart!)
            appStart = nil
        }
        // Because of heavy overlap and desired treatment of AppStart vs
        // ongoing app lifecycle stuff, initialize this now rather than
        // earlier to avoid double-reporting or more complex logic
        initializeAppLifecycleInstrumentation()
    }
    didBecomeActiveNotificationToken = notifCenter.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: didBecomeActiveClosure)
    // didFinishLaunching
    var didFinishLaunchingNotificationToken: NSObjectProtocol?
    let didFinishLaunchingClosure: (Notification) -> Void = { notification in
        appStart?.addEvent(name: notification.name.rawValue)
        if let didFinishLaunchingNotificationToken = didFinishLaunchingNotificationToken {
            notifCenter.removeObserver(didFinishLaunchingNotificationToken)
        }
    }
    didFinishLaunchingNotificationToken = notifCenter.addObserver(forName: UIApplication.didFinishLaunchingNotification, object: nil, queue: .main, using: didFinishLaunchingClosure)
    // willEnterForeground
    var willEnterForegroundNotificationToken: NSObjectProtocol?
    let willEnterForegroundClosure: (Notification) -> Void = { notification in
        wasBackgroundedBeforeWillEnterForeground = UIApplication.shared.applicationState == .background
        appStart?.addEvent(name: notification.name.rawValue)
        if let willEnterForegroundNotificationToken = willEnterForegroundNotificationToken {
            notifCenter.removeObserver(willEnterForegroundNotificationToken)
        }
    }
    willEnterForegroundNotificationToken = notifCenter.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main, using: willEnterForegroundClosure)
    // didBecomeVisible
    var didBecomeVisibleNotificationToken: NSObjectProtocol?
    let didBecomeVisibleClosure: (Notification) -> Void = { notification in
        appStart?.addEvent(name: notification.name.rawValue)
        if let didBecomeVisibleNotificationToken = didBecomeVisibleNotificationToken {
            notifCenter.removeObserver(didBecomeVisibleNotificationToken)
        }
    }
    didBecomeVisibleNotificationToken = notifCenter.addObserver(forName: UIWindow.didBecomeVisibleNotification, object: nil, queue: .main, using: didBecomeVisibleClosure)
}

func constructAppStartSpan() {
    var procStart: Date?
    do {
        procStart = try processStartTime()
        spanStart = procStart!
    } catch {
        // swallow
    }

    let tracer = buildTracer()
    // FIXME more startup details?
    appStart = tracer.spanBuilder(spanName: "AppStart").setStartTime(time: spanStart).startSpan()
    appStart!.setAttribute(key: "component", value: "appstart")
    if let procStart = procStart {
        appStart!.addEvent(name: "process.start", timestamp: procStart)
    }
    if isPrewarm && prewarmAvailable {
        appStart!.setAttribute(key: "process.prewarm", value: true)
    }
    // This is strange looking but I want all the initial spans that happen before didBecomeActive to be kids of the AppStart. Scope is closed at didBecomeActive
    OpenTelemetry.instance.contextProvider.setActiveSpan(appStart!)
}

func sendAppStartSpan() {
    isPrewarm = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1"
    constructAppStartSpan()
    initializeAppStartupListeners()
}
