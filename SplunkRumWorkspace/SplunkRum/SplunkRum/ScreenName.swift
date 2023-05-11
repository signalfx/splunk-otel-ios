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

fileprivate var screenName: String = "unknown"
fileprivate var screenNameManuallySet = false
// Yes, I assume there are swift libraries to do this sort of thing, but nothing
// I could find in the stdlib
fileprivate var lock = NSLock()
fileprivate var screenNameCallbacks: [((String) -> Void)] = []

func emitScreenNameChangedSpan(_ oldName: String, _ newName: String) {
    let now = Date()
    let span = buildTracer().spanBuilder(spanName: Constants.SpanNames.SCREEN_NAME_CHANGE).setStartTime(time: now).startSpan()
    span.setAttribute(key: Constants.AttributeNames.LAST_SCREEN_NAME, value: oldName)
    span.setAttribute(key: Constants.AttributeNames.COMPONENT, value: "ui")
    span.end(time: now)
}

// Assumes main thread
func internal_setScreenName(_ newName: String, _ manual: Bool) {
    var oldName: String?
    var callbacks: [((String) -> Void)] = []
    lock.lock()
    if screenName != newName {
        oldName = screenName
    }
    if manual {
        screenNameManuallySet = true
    }
    // second guard against overwriting manual names
    if manual || !screenNameManuallySet {
        screenName = newName
    }
    callbacks = screenNameCallbacks
    lock.unlock()

    for callback in callbacks {
         callback(screenName)
    }

    // Don't emit the span under the lock
    if oldName != nil && (SplunkRum.configuredOptions?.screenNameSpans ?? true) {
        emitScreenNameChangedSpan(oldName!, newName)
    }
}

func isScreenNameManuallySet() -> Bool {
    lock.lock()
    defer {
        lock.unlock()
    }
    return screenNameManuallySet
}
func getScreenName() -> String {
    lock.lock()
    defer {
        lock.unlock()
    }
    return screenName
}

func addScreenNameCallback(_ callback: @escaping ((String) -> Void)) {
    lock.lock()
    defer {
        lock.unlock()
    }
    screenNameCallbacks.append(callback)
}
