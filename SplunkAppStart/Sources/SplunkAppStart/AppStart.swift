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

    /// Internal Logger.
    let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "AppStart")

    /// Serializes lifecycle state from UIKit notifications and hybrid bridge calls.
    private let stateQueue: DispatchQueue

    /// Identifies work already executing on ``stateQueue``.
    private let stateQueueKey = DispatchSpecificKey<Void>()

    // Notifications and process start
    var notificationTokens: [NSObjectProtocol]?
    var didFinishLaunchingTimestamp: Date?
    var willEnterForegroundTimestamp: Date?
    var willResignActiveTimestamp: Date?
    var didBecomeActiveTimestamp: Date?
    var processStartTimestamp: Date?

    /// Data destination.
    var destination: AppStartDestination = OTelDestination()

    /// Initialize span data.
    var agentInitializeSpanData: AgentInitializeSpanData?

    /// Application prewarm detection.
    var prewarmDetected = false

    /// Background launch detection, optional because we need to detect
    /// ackground launch only once during the initial application launch.
    var backgroundLaunchDetected: Bool?

    /// A flag to prevent duplicate cold starts.
    var coldStartSent = false

    /// Prevents duplicate initial app-start events across automatic and manual tracking.
    var initialAppStartSent = false

    /// Launch origin supplied by a hybrid agent for manual initial app start tracking.
    var capturedLaunchOrigin: AppStartLaunchOrigin?

    /// Background launch threshold in seconds.
    ///
    /// If an application launch duration exceeds this threshold, we consider this launch as being launched in background first.
    /// This threshold is a temporary fix to long cold starts until we improve the background launch detection mechanism.
    let backgroundLaunchThreshold = 10.0


    // MARK: - Public

    /// Shared state.
    public unowned var sharedState: AgentSharedState?


    // MARK: - Initialization

    public required init() {
        let queueName = PackageIdentifier.default(named: "appStartAccess")
        stateQueue = DispatchQueue(label: queueName)
        stateQueue.setSpecific(key: stateQueueKey, value: ())
    }


    // MARK: - Instrumentation

    /// Starts app start detection.
    ///
    /// Detection should be started before receiving the `UIApplication.didFinishLaunchingNotification` notification
    /// in order to correctly detect an application prewarm.
    public func startDetection() {

        // Detect prewarm. ‼️ Prewarm detection must happen before `didFinishLaunching`
        let detectedPrewarm: Bool
        if #available(iOS 15.0, *) {
            detectedPrewarm = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1"
        }
        else {
            detectedPrewarm = false
        }

        // Obtain process start time, which is used as an app start span's start
        let detectedProcessStart: Date?
        do {
            detectedProcessStart = try processStartTime()
        }
        catch {
            detectedProcessStart = nil
            logger.log(level: .warn) {
                "Was not able to obtain process start date, cold start won't be recorded. Error: \(error)"
            }
        }

        withStateAccess {
            prewarmDetected = detectedPrewarm
            processStartTimestamp = detectedProcessStart

            // Start notification listeners
            startNotificationListeners()
        }
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
        withStateAccess {
            agentInitializeSpanData = AgentInitializeSpanData(
                start: start,
                end: end,
                events: AppStartEvent.sortedEvents(from: events),
                configurationSettings: configurationSettings
            )
        }
    }

    /// This method allows bridges (React, Flutter etc.) to track app lifecycle notifications timestamps
    /// to determine and send the app start event manually via an exposed public API.
    ///
    /// Function call is ignored if an initial app start event has been already sent.
    ///
    /// - Parameters:
    ///   - didBecomeActive: A timestamp of the `UIApplication.didBecomeActive` notification. Needed for type determination and sending.
    ///   - didFinishLaunching: An optional timestamp of the `UIApplication.didFinishLaunching` notification.
    ///   Does not determine AppStart type, but is sent as a metadata.
    ///   - willEnterForeground: An optional timestamp of the `UIApplication.willEnterForeground` notification.
    ///   Does not determine AppStart type, but is sent as a metadata.
    public func track(didBecomeActive: Date, didFinishLaunching: Date?, willEnterForeground: Date?) {
        track(initialLifecycle: AppStartLifecycleSnapshot(
            launchOrigin: .unknown,
            didFinishLaunching: didFinishLaunching,
            willEnterForeground: willEnterForeground,
            didBecomeActive: didBecomeActive
        ))
    }

    /// Tracks an initial app start from lifecycle timestamps and launch provenance captured by a hybrid agent.
    ///
    /// - Parameters:
    ///   - didBecomeActive: The captured `UIApplication.didBecomeActiveNotification` timestamp.
    ///   - didFinishLaunching: The captured `UIApplication.didFinishLaunchingNotification` timestamp, if observed.
    ///   - willEnterForeground: The captured `UIApplication.willEnterForegroundNotification` timestamp, if observed.
    ///   - launchOrigin: Whether the process was initially launched for foreground or background execution.
    @_spi(SplunkInternal)
    public func track(
        didBecomeActive: Date,
        didFinishLaunching: Date?,
        willEnterForeground: Date?,
        launchOrigin: AppStartLaunchOrigin
    ) {
        track(initialLifecycle: AppStartLifecycleSnapshot(
            launchOrigin: launchOrigin,
            didFinishLaunching: didFinishLaunching,
            willEnterForeground: willEnterForeground,
            didBecomeActive: didBecomeActive
        ))
    }

    /// Adopts lifecycle evidence captured before a hybrid agent installed the native SDK.
    ///
    /// A complete snapshot is classified and sent immediately. A partial snapshot is retained so
    /// the native lifecycle observer can complete it when `didBecomeActive` is received.
    ///
    /// - Parameter snapshot: Immutable initial lifecycle evidence captured by a hybrid agent.
    @_spi(SplunkInternal)
    public func track(initialLifecycle snapshot: AppStartLifecycleSnapshot) {
        withStateAccess {
            guard !initialAppStartSent else {
                logger.log(level: .debug) {
                    "Initial app start event has been already sent. Ignoring manual track."
                }
                return
            }

            didFinishLaunchingTimestamp = didFinishLaunchingTimestamp ?? snapshot.didFinishLaunching
            willEnterForegroundTimestamp = willEnterForegroundTimestamp ?? snapshot.willEnterForeground
            didBecomeActiveTimestamp = didBecomeActiveTimestamp ?? snapshot.didBecomeActive

            switch (capturedLaunchOrigin, snapshot.launchOrigin) {
            case (nil, _), (.unknown, .foreground), (.unknown, .background):
                capturedLaunchOrigin = snapshot.launchOrigin

            default:
                break
            }

            if didBecomeActiveTimestamp != nil {
                determineAndSendWithStateAccess()
            }
        }
    }


    // MARK: - Type determination

    /// Determines an app start type and sends valid results.
    func determineAndSend() {
        withStateAccess {
            determineAndSendWithStateAccess()
        }
    }

    /// Determines and sends while executing on ``stateQueue``.
    func determineAndSendWithStateAccess() {

        // Reset state for further app start detection
        defer {
            // Clear timestamps
            willEnterForegroundTimestamp = nil
            willResignActiveTimestamp = nil
            didBecomeActiveTimestamp = nil
            capturedLaunchOrigin = nil

            // Clear initialization data as initialization span is sent only once with the cold start
            agentInitializeSpanData = nil
        }

        // Send app start if the type was determined
        if let endTime = didBecomeActiveTimestamp,
            let (determinedType, startTime) = determinedAppStartType(),
            startTime <= endTime
        {
            send(start: startTime, end: endTime, type: determinedType)

            initialAppStartSent = true

            logger.log(level: .debug) {
                "App start log: determined app start type: \(determinedType.rawValue), start time: \(startTime), end time: \(endTime)."
            }
        }
        else {
            logger.log(level: .warn) {
                "Could not determine app start type."
            }
        }
    }

    /// Determines app start type from available notifications timestamps.
    private func determinedAppStartType() -> (AppStartType, Date)? {
        guard let didBecomeActiveTimestamp else {
            return nil
        }

        if let capturedLaunchOrigin {
            return determinedManualAppStartType(
                launchOrigin: capturedLaunchOrigin,
                didBecomeActive: didBecomeActiveTimestamp
            )
        }

        let launchedInBackground: Bool = backgroundLaunchDetected ?? false

        if willResignActiveTimestamp != nil, let startTime = willEnterForegroundTimestamp {
            return (.hot, startTime)
        }

        if !initialAppStartSent,
            launchedInBackground || prewarmDetected,
            let startTime = willEnterForegroundTimestamp
        {
            return (.warm, startTime)
        }

        if !initialAppStartSent, !coldStartSent, let startTime = processStartTimestamp {
            return (.cold, startTime)
        }

        return nil
    }

    /// Determines the initial app start type from lifecycle evidence supplied by a hybrid agent.
    private func determinedManualAppStartType(
        launchOrigin: AppStartLaunchOrigin,
        didBecomeActive: Date
    ) -> (AppStartType, Date)? {
        guard didBecomeActive <= Date() else {
            return nil
        }

        switch launchOrigin {
        case .foreground:
            guard let processStartTimestamp,
                validManualTimestampOrder(start: processStartTimestamp, end: didBecomeActive)
            else {
                return nil
            }

            return (.cold, processStartTimestamp)

        case .background:
            guard let willEnterForegroundTimestamp,
                validManualTimestampOrder(
                    start: willEnterForegroundTimestamp,
                    end: didBecomeActive,
                    allowsLaunchBeforeStart: true
                )
            else {
                return nil
            }

            return (.warm, willEnterForegroundTimestamp)

        case .unknown:
            if prewarmDetected,
                let willEnterForegroundTimestamp,
                validManualTimestampOrder(
                    start: willEnterForegroundTimestamp,
                    end: didBecomeActive,
                    allowsLaunchBeforeStart: true
                )
            {
                return (.warm, willEnterForegroundTimestamp)
            }

            guard let processStartTimestamp,
                let didFinishLaunchingTimestamp,
                let willEnterForegroundTimestamp,
                processStartTimestamp <= didFinishLaunchingTimestamp,
                didFinishLaunchingTimestamp <= willEnterForegroundTimestamp,
                validManualTimestampOrder(start: processStartTimestamp, end: didBecomeActive)
            else {
                return nil
            }

            let launchToForeground = willEnterForegroundTimestamp.timeIntervalSince(didFinishLaunchingTimestamp)
            if launchToForeground > backgroundLaunchThreshold {
                return (.warm, willEnterForegroundTimestamp)
            }

            return (.cold, processStartTimestamp)
        }
    }

    /// Validates optional launch timestamps and the required span bounds for manual tracking.
    private func validManualTimestampOrder(
        start: Date,
        end: Date,
        allowsLaunchBeforeStart: Bool = false
    ) -> Bool {
        guard start <= end else {
            return false
        }

        if let didFinishLaunchingTimestamp,
            didFinishLaunchingTimestamp > end
        {
            return false
        }

        if !allowsLaunchBeforeStart,
            let didFinishLaunchingTimestamp,
            didFinishLaunchingTimestamp < start
        {
            return false
        }

        if let willEnterForegroundTimestamp,
            !(start ... end).contains(willEnterForegroundTimestamp)
        {
            return false
        }

        if let didFinishLaunchingTimestamp,
            let willEnterForegroundTimestamp,
            didFinishLaunchingTimestamp > willEnterForegroundTimestamp
        {
            return false
        }

        return true
    }


    // MARK: - State access

    /// Executes state access serially while allowing internal reentrant calls.
    @discardableResult
    func withStateAccess<T>(_ operation: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: stateQueueKey) != nil {
            return try operation()
        }

        return try stateQueue.sync(execute: operation)
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

            coldStartSent = true
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
        var events: [AppStartEvent] = []

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
