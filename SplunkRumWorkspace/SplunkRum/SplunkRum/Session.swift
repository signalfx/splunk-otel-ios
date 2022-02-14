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

let MAX_SESSION_AGE_SECONDS = 4 * 60 * 60
let MAXSESSIONINACTIVEAGESECONDS = 15 * 60

private var rumSessionId = generateNewSessionId()
private var sessionIdExpiration = Date().addingTimeInterval(TimeInterval(MAX_SESSION_AGE_SECONDS))
private var sessionIdInActivityExpiration = Date().addingTimeInterval(TimeInterval(MAXSESSIONINACTIVEAGESECONDS))
private let sessionIdLock = NSLock()
private var sessionIdCallbacks: [(() -> Void)] = []

func generateNewSessionId() -> String {
    var i=0
    var answer = ""
    while i < 16 {
        i += 1
        let b = Int.random(in: 0..<256)
        answer += String(format: "%02x", b)
    }
    return answer
}

func addSessionIdCallback(_ callback: @escaping (() -> Void)) {
    sessionIdLock.lock()
    defer {
        sessionIdLock.unlock()
    }
    sessionIdCallbacks.append(callback)
}

func getRumSessionId() -> String {
    sessionIdLock.lock()
    var unlocked = false
    var callbacks: [(() -> Void)] = []
    defer {
        if !unlocked {
            sessionIdLock.unlock()
        }
    }
    if Date() > sessionIdExpiration { // expire in 4 hours
        sessionIdExpiration = Date().addingTimeInterval(TimeInterval(MAX_SESSION_AGE_SECONDS))
        sessionIdInActivityExpiration = Date().addingTimeInterval(TimeInterval(MAXSESSIONINACTIVEAGESECONDS))
        rumSessionId = generateNewSessionId()
        callbacks = sessionIdCallbacks
    } else if Date() > sessionIdInActivityExpiration { // expire 15 min
        sessionIdInActivityExpiration = Date().addingTimeInterval(TimeInterval(MAXSESSIONINACTIVEAGESECONDS))
        rumSessionId = generateNewSessionId()
        callbacks = sessionIdCallbacks
    } else { // no timer expire but activity done on screen
        sessionIdInActivityExpiration = Date().addingTimeInterval(TimeInterval(MAXSESSIONINACTIVEAGESECONDS))
    }
    sessionIdLock.unlock()
    unlocked = true
    for callback in callbacks {
        callback()
    }
    return rumSessionId
}
