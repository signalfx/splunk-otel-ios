//
/*
Copyright 2025 Splunk Inc.

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

internal import CiscoLogger
import SplunkCommon
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
    let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "AppStart")

    // Notifications and process start
    var notificationTokens: [NSObjectProtocol]?
    var didFinishLaunchingTimestamp: Date?
    var willEnterForegroundTimestamp: Date?
    var willResignActiveTimestamp: Date?
    var didBecomeActiveTimestamp: Date?
    var processStartTimestamp: Date?

    // Destination
    var destination: AppStartDestination = OTelDestination()

    // Initialize span data
    var agentInitializeSpanData: AgentInitializeSpanData?

    // Application prewarm detection
    var prewarmDetected = false

    // Background launch detection, optional because we need to detect
    // background launch only once during the initial application launch
    var backgroundLaunchDetected: Bool?


    // MARK: - Public

    /// Shared state
    public unowned var sharedState: AgentSharedState?


    // MARK: - Initialization

    /// Module conformance
    public required init() {}


    // MARK: - Instrumentation

    /// Starts app start detection. Detection should be started before receiving the `UIApplication.didFinishLaunchingNotification` notification
    /// in order to correctly detect an application prewarm.
    public func startDetection() {

        // Detect prewarm. ‼️ Prewarm detection must happen before `didFinishLaunching`
        prewarmDetected = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1"

        // Obtain process start time, which is used as an app start span's start
        do {
            processStartTimestamp = try processStartTime()
        } catch {
            logger.log(level: .warn) {
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

    /// Report agent initialization metrics, which will be sent in the Initialization span as an AppStart's child span.
    ///
    /// - Parameters:
    ///   - start: Agent's initialization start timestamp.
    ///   - end: Agent's initialization end timestamp.
    ///   - events: Report any number of events, which will be reported as Initialize span's events. Event name as a key, timestamp as a value for each event.
    ///   - configurationSettings: Report agent configuration settings.
    public func reportAgentInitialize(start: Date, end: Date, events: [String: Date], configurationSettings: [String: String]) {
        agentInitializeSpanData = AgentInitializeSpanData(
            start: start,
            end: end,
            events: AppStartEvent.sortedEvents(from: events),
            configurationSettings: configurationSettings
        )
    }


    // MARK: - Type determination

    /// Determines an app start type from available notifications timestamps, sends valid results.
    func determineAndSend() {

        var determinedType: AppStartType?
        var startTime: Date?
        let endTime = Date()

        // Reset state for further app start detection
        defer {
            // Clear timestamps
            willEnterForegroundTimestamp = nil
            willResignActiveTimestamp = nil
            didBecomeActiveTimestamp = nil

            // Clear initialization data as initialization span is sent only once with the cold start
            agentInitializeSpanData = nil
        }

        var launchedInBackground = false
        if let backgroundLaunchDetected {
            launchedInBackground = backgroundLaunchDetected
        }

        // Hot start
        if willResignActiveTimestamp != nil {
            if let willEnterForegroundTimestamp, didBecomeActiveTimestamp != nil {
                startTime = willEnterForegroundTimestamp
                determinedType = .hot
            }

        // Warm start
        } else if launchedInBackground || prewarmDetected {
            if let willEnterForegroundTimestamp, didBecomeActiveTimestamp != nil {
                startTime = willEnterForegroundTimestamp
                determinedType = .warm
            }

        // Cold start
        } else if let processStartTimestamp, didFinishLaunchingTimestamp != nil {
            if didBecomeActiveTimestamp != nil {
                startTime = processStartTimestamp
                determinedType = .cold
            }
        }

        // Send app start if the type was determined
        if let determinedType, let startTime {
            send(start: startTime, end: endTime, type: determinedType)

            logger.log(level: .debug) {
                "App start log: determined app start type: \(determinedType.rawValue), start time: \(startTime), end time: \(endTime)."
            }

        } else if didFinishLaunchingTimestamp != nil {
            logger.log(level: .debug) {
                "App start log: could not determine, skipping."
            }

        } else {
            logger.log(level: .warn) {
                "Could not determine app start type, the agent was likely initialized later than receiving the didFinishLaunching notification."
            }
        }
    }


    // MARK: - Sending

    /// Sends results into a destination.
    private func send(start: Date, end: Date, type: AppStartType) {

        var events: [AppStartEvent]?
        var initializeData: AgentInitializeSpanData?

        // Send app start events and initialize span in a cold start only
        if type == .cold {
            events = coldStartEvents(startTime: start)
            initializeData = agentInitializeSpanData
        }

        let appStartData = AppStartSpanData(
            type: type,
            start: start,
            end: end,
            events: events
        )

        destination.send(appStart: appStartData, agentInitialize: initializeData, sharedState: sharedState)
    }


    // MARK: - Cold start events

    private func coldStartEvents(startTime: Date) -> [AppStartEvent] {
        var events = [AppStartEvent]()

        events.append(AppStartEvent(name: "process.start", timestamp: startTime))

        if let didFinishLaunchingTimestamp {
            events.append(
                AppStartEvent(
                    name: UIApplication.didFinishLaunchingNotification.rawValue,
                    timestamp: didFinishLaunchingTimestamp
                )
            )
        }

        if let willEnterForegroundTimestamp {
            events.append(
                AppStartEvent(
                    name: UIApplication.willEnterForegroundNotification.rawValue,
                    timestamp: willEnterForegroundTimestamp
                )
            )
        }

        if let didBecomeActiveTimestamp {
            events.append(
                AppStartEvent(
                    name: UIApplication.didBecomeActiveNotification.rawValue,
                    timestamp: didBecomeActiveTimestamp
                )
            )
        }

        return events
    }
}
