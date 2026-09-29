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
    var backgroundLaunchConfidence: AppLifecycleRecorder.LaunchOriginConfidence = .unknown

    /// A flag to prevent duplicate cold starts.
    var coldStartSent = false

    /// Explicitly tracks the initial AppStart resolution.
    var initialAppStartState = AppStartResolutionState.pending

    /// Cancels the bounded wait for a partial hybrid handoff.
    var initialHandoffTimeoutWorkItem: DispatchWorkItem?

    /// Holds the recorder snapshot until the agent initialization child span data exists.
    var deferredLifecycleSnapshot: AppStartLifecycleSnapshot?
    var shouldDeferInitialLifecycleResolution = false

    /// Launch provenance captured by a hybrid integration before the SDK was installed.
    var capturedLaunchOrigin: AppStartLaunchOrigin?
    var capturedLaunchOriginConfidence: AppLifecycleRecorder.LaunchOriginConfidence = .unknown

    /// Keeps an inferred core background snapshot pending until a hybrid integration
    /// can provide the observed launch provenance.
    var awaitingObservedBackgroundHandoff = false

    /// Background launch threshold in seconds.
    ///
    /// Delays beyond this threshold are only an inferred signal. They are not
    /// sufficient to emit a warm start because a long foreground splash screen
    /// can produce the same timing.
    let backgroundLaunchThreshold = 10.0

    /// Maximum valid AppStart duration.
    ///
    /// This is a validity guard, not the launch classifier. The guard is intentionally
    /// high and only applies when launch provenance is
    /// untrusted. Trusted foreground and background launches must remain observable
    /// even when the host application's splash/startup work is slow.
    var maxAppStartDuration: TimeInterval = 60.0

    /// Counts suppressed initial measurements by reason for rollout diagnostics.
    ///
    /// This stays local to the module and is not emitted as customer telemetry.
    var suppressionCounts: [AppStartSuppressionReason: Int] = [:]

    /// Maximum time to wait for an asynchronous hybrid lifecycle handoff.
    var initialHandoffTimeout: TimeInterval = 5.0


    // MARK: - Public

    /// Shared state.
    public unowned var sharedState: AgentSharedState?


    // MARK: - Initialization

    public required init() {}

    func markBackgroundLaunchDetected(explicitlyObserved: Bool) {
        backgroundLaunchDetected = true
        backgroundLaunchConfidence = explicitlyObserved ? .observed : .inferred
    }


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

    /// Defers the initial lifecycle resolution until agent initialization data is available.
    @_spi(SplunkInternal)
    public func deferInitialLifecycleResolution() {
        shouldDeferInitialLifecycleResolution = true
        deferredLifecycleSnapshot = nil
    }

    /// Resumes an initial lifecycle snapshot captured while the agent was being customized.
    @_spi(SplunkInternal)
    public func resumeInitialLifecycleResolution() {
        let snapshot = deferredLifecycleSnapshot
        deferredLifecycleSnapshot = nil
        shouldDeferInitialLifecycleResolution = false

        guard let snapshot else {
            return
        }

        consume(coreLifecycle: nil, snapshot: snapshot)
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

            determineAndSend(allowLegacyManualTrackingFallback: true)
        }
    }

    /// Tracks an initial app start using lifecycle evidence captured before SDK installation.
    ///
    /// A snapshot may be partial when installation happens before the application becomes active.
    /// In that case the native listener completes the snapshot when it observes the real event.
    /// This is the preferred handoff path when an integration can provide a complete
    /// or partial snapshot. For compatibility, a legacy
    /// `track(didBecomeActive:didFinishLaunching:willEnterForeground:)` call may
    /// complete a snapshot that is still pending, for example when an older hybrid
    /// adapter supplies the missing foreground boundary. Do not use the two APIs as
    /// independent handoffs for different initial activations.
    @_spi(SplunkInternal)
    public func track(initialLifecycle snapshot: AppStartLifecycleSnapshot) {
        executeOnMain { [self] in
            guard !initialAppStartState.isTerminal else {
                logger.log(level: .debug) {
                    "Initial app start event has been already sent. Ignoring lifecycle snapshot."
                }
                return
            }

            let lifecycleSegments = initialLifecycleSegments(from: snapshot)
            merge(initialLifecycle: lifecycleSegments.initial)

            if capturedLaunchOriginConfidence == .observed {
                awaitingObservedBackgroundHandoff = false
            }

            if awaitingObservedBackgroundHandoff {
                scheduleInitialHandoffTimeout()
            }
            else if didBecomeActiveTimestamp != nil, !isWaitingForBackgroundForegroundBoundary {
                cancelInitialHandoffTimeout()
                determineAndSend()
                if initialAppStartState.isTerminal {
                    replaySubsequentLifecycleEvents(lifecycleSegments.subsequent)
                }
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
}
