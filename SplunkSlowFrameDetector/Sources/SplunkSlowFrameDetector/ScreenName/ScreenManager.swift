//
/*
Copyright 2024 Splunk Inc.

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
import OpenTelemetryApi
import OpenTelemetrySdk


// Global convenience functions to maintain compatibility with legacy code

// TODO: Consider lifting this up out of this module and into SplunkAgent
//
// we need some team input on this.
//
// For example, it might go under a new group "ScreenContent":
// SplunkAgent ->
//            Agent ->
//                    ScreenContent ->
//                                    ScreenName.swift
//


public func setScreenName(_ newName: String, manual: Bool = false) {
    ScreenManager.shared.setScreenName(newName, manual: manual)
}


@discardableResult
public func getScreenName() -> String {
    return ScreenManager.shared.getScreenName()
}


@discardableResult
public func isScreenNameManuallySet() -> Bool {
    return ScreenManager.shared.isScreenNameManuallySet()
}


public func addScreenNameChangeCallback(_ callback: @escaping (String) -> Void) {
    ScreenManager.shared.addScreenNameChangeCallback(callback)
}



// MARK: - ScreenManager singleton

public class ScreenManager: NSObject {

    public static let shared = ScreenManager()

    private var _screenName: String = "unknown"
    private var _screenNameManuallySet: Bool = false
    private var screenNameCallbacks: [(String) -> Void] = []

    private let queue = DispatchQueue(label: "com.splunk.mrum.ios.screenManager.queue")



    // MARK: - Required initializer

    override private init() {}



    // MARK: - Public methods

    public func setScreenName(_ newName: String, manual: Bool = false) {
        queue.sync {
            let oldName = _screenName
            if manual {
                _screenNameManuallySet = true
            }
            if manual || !_screenNameManuallySet {
                if _screenName != newName {
                    _screenName = newName
                    notifyCallbacks(newName: newName)
                    emitScreenNameChangedSpan(oldName: oldName, newName: newName)
                }
            }
        }
    }


    public func getScreenName() -> String {
        return queue.sync {
            _screenName
        }
    }


    public func isScreenNameManuallySet() -> Bool {
        return queue.sync {
            _screenNameManuallySet
        }
    }


    public func addScreenNameChangeCallback(_ callback: @escaping (String) -> Void) {
        queue.sync {
            screenNameCallbacks.append(callback)
        }
    }


    // MARK: - Private methods

    private func notifyCallbacks(newName: String) {
        // Execute callbacks outside the queue to prevent deadlocks
        let callbacks = screenNameCallbacks
        DispatchQueue.global().async {
            for callback in callbacks {
                callback(newName)
            }
        }
    }


    // TODO: Hook this up with the real OTEL code
    private func emitScreenNameChangedSpan(oldName: String, newName: String) {
        // OpenTelemetrySdk.emitScreenNameChangedSpan(oldName: oldName, newName: newName)
        print("calling emitScreenNameChangedSpan")
    }
}

