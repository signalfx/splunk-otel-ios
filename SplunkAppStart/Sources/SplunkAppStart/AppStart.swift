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
@_spi(SplunkInternal) import SplunkCommon
import UIKit

enum AppStartSuppressionReason: String, Equatable, Hashable {
    case unknownLaunchOrigin
    case maxDurationExceeded
    case missingDidBecomeActive
    case invalidTimestampOrder
    case missingForegroundBoundary
    case missingProcessStart
    case backgroundWithoutForeground
}

enum AppStartResolutionState: Equatable {
    case pending
    case emitted
    case suppressed(AppStartSuppressionReason)

    var isTerminal: Bool {
        switch self {
        case .pending:
            return false

        case .emitted,
             .suppressed:
            return true
        }
    }
}

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
    /// background launch only once during the initial application launch.
    var backgroundLaunchDetected: Bool?

    /// A flag to prevent duplicate cold starts.
    var coldStartSent = false

    /// Explicitly tracks the initial AppStart resolution.
    var initialAppStartState = AppStartResolutionState.pending

    /// Cancels the bounded wait for a partial hybrid handoff.
    var initialHandoffTimeoutWorkItem: DispatchWorkItem?

    /// Launch provenance captured by a hybrid integration before the SDK was installed.
    var capturedLaunchOrigin: AppStartLaunchOrigin?

    /// Background launch threshold in seconds.
    ///
    /// If an application launch duration exceeds this threshold, we consider this launch as being launched in background first.
    /// This threshold is a temporary fix to long cold starts until we improve the background launch detection mechanism.
    let backgroundLaunchThreshold = 10.0

    /// Maximum valid AppStart duration. This is a validity guard, not the launch classifier.
    ///
    /// The guard is intentionally high and only applies when launch provenance is
    /// untrusted. Trusted foreground and background launches must remain observable
    /// even when the host application's splash/startup work is slow.
    var maxAppStartDuration: TimeInterval = 60.0

    /// Counts suppressed initial measurements by reason for rollout diagnostics.
    /// This stays local to the module and is not emitted as customer telemetry.
    var suppressionCounts: [AppStartSuppressionReason: Int] = [:]

    /// Maximum time to wait for an asynchronous hybrid lifecycle handoff.
    var initialHandoffTimeout: TimeInterval = 5.0


    // MARK: - Public

    /// Shared state.
    public unowned var sharedState: AgentSharedState?


    // MARK: - Initialization

    public required init() {}


    // MARK: - Instrumentation

    /// Starts app start detection.
    ///
    /// Detection should be started before receiving the `UIApplication.didFinishLaunchingNotification` notification
    /// in order to correctly detect an application prewarm.
    public func startDetection() {

        // Detect prewarm. ‼️ Prewarm detection must happen before `didFinishLaunching`
        if #available(iOS 15.0, *) {
            prewarmDetected = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1"
        }
        else {
            prewarmDetected = false
        }

        // Obtain process start time, which is used as an app start span's start
        do {
            processStartTimestamp = try processStartTime()
        }
        catch {
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
        cancelInitialHandoffTimeout()
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
    ///
    /// Use this API when an integration supplies the lifecycle evidence. Timestamps already
    /// captured by native listeners take precedence. Use `track(initialLifecycle:)` when the
    /// handoff may be partial and native listeners may complete it later.
    public func track(didBecomeActive: Date, didFinishLaunching: Date?, willEnterForeground: Date?) {
        executeOnMain { [self] in
            guard !initialAppStartState.isTerminal else {
                logger.log(level: .debug) {
                    "Initial app start event has been already sent. Ignoring manual track."
                }
                return
            }

            didBecomeActiveTimestamp = didBecomeActiveTimestamp ?? didBecomeActive
            didFinishLaunchingTimestamp = didFinishLaunchingTimestamp ?? didFinishLaunching
            willEnterForegroundTimestamp = willEnterForegroundTimestamp ?? willEnterForeground

            determineAndSend()
        }
    }

    /// Tracks an initial app start using lifecycle evidence captured before SDK installation.
    ///
    /// A snapshot may be partial when installation happens before the application becomes active.
    /// In that case the native listener completes the snapshot when it observes the real event.
    /// This API and `track(didBecomeActive:didFinishLaunching:willEnterForeground:)` are
    /// alternative handoff paths and must not be mixed for the same initial activation.
    @_spi(SplunkInternal)
    public func track(initialLifecycle snapshot: AppStartLifecycleSnapshot) {
        executeOnMain { [self] in
            guard !initialAppStartState.isTerminal else {
                logger.log(level: .debug) {
                    "Initial app start event has been already sent. Ignoring lifecycle snapshot."
                }
                return
            }

            merge(initialLifecycle: snapshot)

            if didBecomeActiveTimestamp != nil, !isWaitingForBackgroundForegroundBoundary {
                cancelInitialHandoffTimeout()
                determineAndSend()
            }
            else if isWaitingForBackgroundForegroundBoundary {
                cancelInitialHandoffTimeout()
            }
            else {
                scheduleInitialHandoffTimeout()
            }
        }
    }

    func executeOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        }
        else {
            // Lifecycle instrumentation must never block a host thread waiting for the main
            // thread. Both bridge integrations already marshal their handoff to main, while
            // this fallback keeps direct off-main callers safe and serializes their update.
            DispatchQueue.main.async(execute: work)
        }
    }


    // MARK: - Type determination

    /// Determines an app start type and sends valid results.
    func determineAndSend() {

        if case .suppressed = initialAppStartState {
            logger.log(level: .debug) {
                "App start resolution has already reached a terminal state. Ignoring lifecycle event."
            }
            return
        }

        guard !isWaitingForBackgroundForegroundBoundary else {
            return
        }

        // Reset state for further app start detection
        defer {
            // Clear timestamps
            didFinishLaunchingTimestamp = nil
            willEnterForegroundTimestamp = nil
            willResignActiveTimestamp = nil
            didBecomeActiveTimestamp = nil
            capturedLaunchOrigin = nil

            // Clear initialization data as initialization span is sent only once with the cold start
            agentInitializeSpanData = nil
        }

        guard let endTime = didBecomeActiveTimestamp else {
            logger.log(level: .debug) {
                "Cannot determine app start without a didBecomeActive timestamp."
            }
            return
        }

        // Send app start if the type was determined
        if let (determinedType, startTime) = determinedAppStartType() {
            guard startTime.timeIntervalSinceReferenceDate.isFinite,
                endTime.timeIntervalSinceReferenceDate.isFinite,
                startTime <= endTime
            else {
                suppressInitialAppStart(reason: .invalidTimestampOrder)
                return
            }

            let duration = endTime.timeIntervalSince(startTime)
            let provenanceIsTrusted = capturedLaunchOrigin == .foreground
                || capturedLaunchOrigin == .background
                || backgroundLaunchDetected == true

            guard duration.isFinite,
                !provenanceIsTrusted && duration <= maxAppStartDuration || provenanceIsTrusted
            else {
                suppressInitialAppStart(reason: .maxDurationExceeded)
                return
            }

            send(start: startTime, end: endTime, type: determinedType)
            resolveInitialAppStart(as: .emitted)

            logger.log(level: .debug) {
                "App start log: determined app start type: \(determinedType.rawValue), start time: \(startTime), end time: \(endTime)."
            }
        }
        else {
            suppressInitialAppStart(reason: suppressionReason())
        }
    }

    /// Determines app start type from available notifications timestamps.
    private func determinedAppStartType() -> (AppStartType, Date)? {
        guard let didBecomeActiveTimestamp else {
            return nil
        }

        // Prewarm means that process start is not a valid user-visible cold-start anchor.
        // Check it before hybrid launch origin because UIApplication may report .active or
        // .inactive for a prewarmed process when the early hybrid observer runs.
        if prewarmDetected,
            let startTime = willEnterForegroundTimestamp,
            startTime <= didBecomeActiveTimestamp
        {
            return (.warm, startTime)
        }

        if let capturedLaunchOrigin {
            return determinedSnapshotAppStartType(launchOrigin: capturedLaunchOrigin)
        }

        let launchedInBackground = backgroundLaunchDetected

        if willResignActiveTimestamp != nil, let startTime = willEnterForegroundTimestamp {
            return (.hot, startTime)
        }

        if !initialAppStartState.isTerminal,
            launchedInBackground == true || prewarmDetected,
            let startTime = willEnterForegroundTimestamp
        {
            return (.warm, startTime)
        }

        if !initialAppStartState.isTerminal, !coldStartSent, let startTime = processStartTimestamp {
            if launchedInBackground == nil {
                guard let didFinishLaunchingTimestamp,
                    let willEnterForegroundTimestamp,
                    willEnterForegroundTimestamp >= didFinishLaunchingTimestamp
                else {
                    return nil
                }

                if willEnterForegroundTimestamp.timeIntervalSince(didFinishLaunchingTimestamp) > backgroundLaunchThreshold {
                    // A delayed foreground boundary without trusted background
                    // provenance is intentionally suppressed; it must not become
                    // an artificially long cold start or an inferred warm start.
                    return nil
                }
            }

            return (.cold, startTime)
        }

        return nil
    }

    /// Determines an initial AppStart from explicit hybrid lifecycle evidence.
    private func determinedSnapshotAppStartType(launchOrigin: AppStartLaunchOrigin) -> (AppStartType, Date)? {
        guard let didBecomeActiveTimestamp else {
            return nil
        }

        switch launchOrigin {
        case .foreground:
            guard let processStartTimestamp,
                processStartTimestamp <= didBecomeActiveTimestamp,
                validSnapshotEventTimes(end: didBecomeActiveTimestamp)
            else {
                return nil
            }

            return (.cold, processStartTimestamp)

        case .background:
            guard let willEnterForegroundTimestamp,
                willEnterForegroundTimestamp <= didBecomeActiveTimestamp,
                validSnapshotEventTimes(end: didBecomeActiveTimestamp)
            else {
                return nil
            }

            return (.warm, willEnterForegroundTimestamp)

        case .unknown:
            // An unknown origin is not evidence for either cold or warm start. In
            // particular, do not use a duration threshold to turn untrusted
            // provenance into a customer-visible measurement.
            return nil
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

    // MARK: - Resolution

    func merge(initialLifecycle snapshot: AppStartLifecycleSnapshot, acceptUnknownOrigin: Bool = true) {
        didFinishLaunchingTimestamp = didFinishLaunchingTimestamp ?? snapshot.didFinishLaunching
        willEnterForegroundTimestamp = willEnterForegroundTimestamp ?? snapshot.willEnterForeground
        didBecomeActiveTimestamp = didBecomeActiveTimestamp ?? snapshot.didBecomeActive
        prewarmDetected = prewarmDetected || snapshot.prewarmDetected

        // Replay the same ordered evidence used by AppState. The scalar fields
        // above preserve compatibility with integrations that only provide three
        // timestamps, while the history fills in transitions such as
        // willResignActive and willTerminate that are otherwise lost on handoff.
        for record in snapshot.events {
            mergeCoreLifecycleEvent(record.event)
        }

        if acceptUnknownOrigin || snapshot.launchOrigin != .unknown {
            capturedLaunchOrigin = capturedLaunchOrigin ?? snapshot.launchOrigin
        }
    }

    func processCoreLifecycleEvent(_ event: AppLifecycleRecorder.Event, resolve: Bool = true) {
        mergeCoreLifecycleEvent(event)

        if resolve {
            switch event {
            case .didBecomeActive:
                determineAndSend()

            case .willTerminate:
                if !initialAppStartState.isTerminal {
                    suppressInitialAppStart(reason: suppressionReason())
                }

            default:
                break
            }
        }
    }

    private func mergeCoreLifecycleEvent(_ event: AppLifecycleRecorder.Event) {
        switch event {
        case let .didFinishLaunching(timestamp):
            didFinishLaunchingTimestamp = didFinishLaunchingTimestamp ?? timestamp

        case let .willEnterForeground(timestamp):
            willEnterForegroundTimestamp = willEnterForegroundTimestamp ?? timestamp

        case let .didBecomeActive(timestamp):
            didBecomeActiveTimestamp = didBecomeActiveTimestamp ?? timestamp

        case let .willResignActive(timestamp):
            willResignActiveTimestamp = willResignActiveTimestamp ?? timestamp

        case .didEnterBackground,
             .willTerminate:
            break
        }
    }

    func scheduleInitialHandoffTimeout() {
        guard initialHandoffTimeoutWorkItem == nil,
            !initialAppStartState.isTerminal,
            !isWaitingForBackgroundForegroundBoundary
        else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.initialAppStartState.isTerminal else {
                return
            }

            initialHandoffTimeoutWorkItem = nil

            if isWaitingForBackgroundForegroundBoundary {
                return
            }

            if didBecomeActiveTimestamp == nil {
                suppressInitialAppStart(reason: .missingDidBecomeActive)
            }
            else {
                determineAndSend()
            }
        }

        initialHandoffTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + initialHandoffTimeout,
            execute: workItem
        )
    }

    func cancelInitialHandoffTimeout() {
        initialHandoffTimeoutWorkItem?.cancel()
        initialHandoffTimeoutWorkItem = nil
    }

    private func resolveInitialAppStart(as state: AppStartResolutionState) {
        guard !initialAppStartState.isTerminal else {
            return
        }

        initialAppStartState = state
        cancelInitialHandoffTimeout()
    }

    private func suppressInitialAppStart(reason: AppStartSuppressionReason) {
        guard !initialAppStartState.isTerminal else {
            return
        }

        resolveInitialAppStart(as: .suppressed(reason))
        suppressionCounts[reason, default: 0] += 1

        logger.log(level: .warn) {
            "AppStart measurement suppressed. reason=\(reason.rawValue)"
        }
    }

    private func suppressionReason() -> AppStartSuppressionReason {
        if isWaitingForBackgroundForegroundBoundary {
            return .backgroundWithoutForeground
        }

        guard didBecomeActiveTimestamp != nil else {
            return .missingDidBecomeActive
        }

        guard let didBecomeActiveTimestamp,
            validSnapshotEventTimes(end: didBecomeActiveTimestamp)
        else {
            return .invalidTimestampOrder
        }

        if let capturedLaunchOrigin {
            switch capturedLaunchOrigin {
            case .background:
                return willEnterForegroundTimestamp == nil ? .missingForegroundBoundary : .unknownLaunchOrigin

            case .unknown:
                return .unknownLaunchOrigin

            case .foreground:
                return processStartTimestamp == nil ? .missingProcessStart : .unknownLaunchOrigin
            }
        }

        if backgroundLaunchDetected == nil {
            return .unknownLaunchOrigin
        }

        return .unknownLaunchOrigin
    }

    var isWaitingForBackgroundForegroundBoundary: Bool {
        capturedLaunchOrigin == .background && willEnterForegroundTimestamp == nil
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
