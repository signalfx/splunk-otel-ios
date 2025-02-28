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

import SplunkLogger
import SplunkSharedProtocols
import UIKit

/// Defines an app start type.
public enum AppStartType: String {

    /// Cold start is a complete application launch, with no resources preloaded.
    case cold

    /// Warm start is an application launch when the application was either prewarmed, or launched in the background first.
    case warm

    /// Hot start is every application launch after an application was already launched at least once.
    /// Hot start begins with the `willEnterForeground` notification, ends with the `didBecomeActive` notification.
    ///
    /// Note: Opening the application right after closing the application in a quick succession causes the `willEnterForeground` to not trigger.
    /// We don't handle this case and we do not consider this scenario as an app start in the current implementation.
    case hot
}

/// AppStart determines and measures an application's start type (cold, warm, hot), by listening to Application's lifecycle notifications,
/// and sends results into a destination (OTel span as a default).
public final class AppStart {

    // MARK: - Private

    // Internal Logger
    let internalLogger = InternalLogger(configuration: .default(subsystem: "Splunk Agent", category: "AppStart"))

    // Notifications and process start
    var notificationTokens: [NSObjectProtocol]?
    var didFinishLaunchingTimestamp: Date?
    var willEnterForegroundTimestamp: Date?
    var willResignActiveTimestamp: Date?
    var didBecomeActiveDate: Date?
    var processStartDate: Date?

    // Destination
    var destination: AppStartDestination = OTelDestination()

    // Application prewarm detection
    var prewarmDetected = false

    // Background launch detection, optional because we need to detect
    // background launch only once during the initial application launch.
    var backgroundLaunchDetected: Bool?


    // MARK: - Public

    // Shared state
    public unowned var sharedState: AgentSharedState?


    // MARK: - Initialization

    // Module conformance
    public required init() {}


    // MARK: - Instrumentation

    /// Starts app start detection. Detection should be started before receiving the `UIApplication.didFinishLaunchingNotification` notification
    /// in order to correctly detect an application prewarm.
    public func startDetection() {

        // Detect prewarm. ‼️ Prewarm detection must happen before `didFinishLaunching`
        prewarmDetected = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1"

        // Obtain process start time, which is used as an app start span's start
        do {
            processStartDate = try processStartTime()
        } catch {
            internalLogger.log(level: .warn) {
                "Was not able to obtain process start date, cold start won't be recorded. Error: \(error)"
            }
        }

        // Start notification listeners
        startNotificationListeners()
    }

    /// Stops app start detection.
    public func stopDetection() {
        stopNotificationListeners()
    }


    // MARK: - Sending

    /// Determines an app start type from available notifications timestampts, sends results into a destination if results are valid.
    func determineAndSend() {

        var determinedType: AppStartType?
        var startTime: Date?

        let endTime = Date()

        // Reset state for further app start detection
        defer {
            willEnterForegroundTimestamp = nil
            willResignActiveTimestamp = nil
            didBecomeActiveDate = nil
        }

        var launchedInBackground = false
        if let backgroundLaunchDetected {
            launchedInBackground = backgroundLaunchDetected
        }

        // Hot start
        if willResignActiveTimestamp != nil {
            if let willEnterForegroundTimestamp, didBecomeActiveDate != nil {
                startTime = willEnterForegroundTimestamp
                determinedType = .hot
            }

        // Warm start
        } else if launchedInBackground || prewarmDetected {
            if let willEnterForegroundTimestamp, didBecomeActiveDate != nil {
                startTime = willEnterForegroundTimestamp
                determinedType = .warm
            }

        // Cold start
        } else if let processStartDate, didFinishLaunchingTimestamp != nil {
            if didBecomeActiveDate != nil {
                startTime = processStartDate
                determinedType = .cold
            }
        }

        // Send app start if the type was determined
        if let determinedType, let startTime {
            let events = determinedType == .cold ? coldStartEvents(startTime: startTime) : nil

            destination.send(type: determinedType, start: startTime, end: endTime, sharedState: sharedState, events: events)

            internalLogger.log(level: .debug) {
                "App start log: determined app start type: \(determinedType.rawValue), start time: \(startTime), end time: \(endTime)."
            }

        } else if didFinishLaunchingTimestamp != nil {
            internalLogger.log(level: .debug) {
                "App start log: could not determine, skipping."
            }

        } else {
            internalLogger.log(level: .warn) {
                "Could not determine app start type, the agent was likely initialized later than receiving the didFinishLaunching notification."
            }
        }
    }


    // MARK: - Cold start events

    private func coldStartEvents(startTime: Date) -> [String: Date] {
        var events = [String: Date]()

        events["process.start"] = startTime

        if let didFinishLaunchingTimestamp {
            events[UIApplication.didFinishLaunchingNotification.rawValue] = didFinishLaunchingTimestamp
        }

        if let willEnterForegroundTimestamp {
            events[UIApplication.willEnterForegroundNotification.rawValue] = willEnterForegroundTimestamp
        }

        if let didBecomeActiveDate {
            events[UIApplication.didBecomeActiveNotification.rawValue] = didBecomeActiveDate
        }

        return events
    }
}
