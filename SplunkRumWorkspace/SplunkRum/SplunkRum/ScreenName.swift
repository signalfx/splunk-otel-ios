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

// Assumes main thread
func internal_setScreenName(_ newName: String) {
    lock.lock()
    defer {
        lock.unlock()
    }
    screenName = newName
}

// Assumes main thread
func internal_manuallySetScreenName(_ newName: String) {
    lock.lock()
    defer {
        lock.unlock()
    }
    screenNameManuallySet = true
    screenName = newName
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
