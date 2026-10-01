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
import Foundation
import SplunkCommon

/// Defines an app start type.
public enum AppStartType: String {

    /// Cold start is a complete application launch, with no resources preloaded.
    case cold

    /// Warm start is an application launch when the application was either prewarmed,
    /// or launched in the background first.
    case warm

    /// Hot start is an activation after the application was already running.
    case hot
}

/// Measures application activation from one lifecycle observer and one state machine.
public final class AppStart {

    // MARK: - Inline types

    typealias ProcessingOutput = (
        action: AppStartReducer.Action?,
        agentInitialize: AgentInitializeSpanData?
    )

    // MARK: - Private

    private let lock = NSLock()
    private var state: AppStartReducer.State
    private var agentInitializeSpanData: AgentInitializeSpanData?

    // Internal only because notification handling lives in a separate file.
    // Access the generation and tokens exclusively while holding this lock.
    let notificationLock = NSLock()
    let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "AppStart")
    var notificationGeneration: UInt64 = 0
    var notificationTokens: [NSObjectProtocol]?

    /// Data destination.
    var destination: AppStartDestination = OTelDestination()


    // MARK: - Public

    /// Shared state.
    public unowned var sharedState: AgentSharedState?


    // MARK: - Initialization

    public required init() {
        let prewarmed: Bool

        if #available(iOS 15.0, *) {
            prewarmed = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1"
        }
        else {
            prewarmed = false
        }

        state = .initial(
            AppStartReducer.Evidence(
                processStart: nil,
                launchOrigin: prewarmed ? .prewarmed : .unknown,
                didFinishLaunching: nil,
                foregroundBoundary: nil,
                didBecomeActive: nil
            )
        )

        do {
            processStartTimestamp = try processStartTime()
        }
        catch {
            logger.log(level: .warn) {
                "Could not obtain process start time. A cold AppStart will be suppressed. Error: \(error)"
            }
        }
    }

    deinit {
        stopNotificationListeners(invalidateState: false)
    }


    // MARK: - Instrumentation

    /// Starts app start detection.
    public func startDetection() {
        startNotificationListeners()
    }

    /// Stops app start detection.
    public func stopDetection() {
        stopNotificationListeners(invalidateState: true)
    }

    /// Reports agent initialization metrics sent as a child of a cold AppStart span.
    public func reportAgentInitialize(
        start: Date,
        end: Date,
        events: [String: Date],
        configurationSettings: [String: String]
    ) {
        let data = AgentInitializeSpanData(
            start: start,
            end: end,
            events: AppStartEvent.sortedEvents(from: events),
            configurationSettings: configurationSettings
        )

        withLock {
            guard case .initial = state else {
                return
            }

            agentInitializeSpanData = data
        }
    }

    /// Compatibility handoff for existing hybrid integrations.
    ///
    /// Legacy timestamps cannot prove launch origin. A completed handoff is safely
    /// suppressed unless native lifecycle evidence has already established it.
    public func track(
        didBecomeActive: Date,
        didFinishLaunching: Date?,
        willEnterForeground: Date?
    ) {
        track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .unknown,
                didFinishLaunching: didFinishLaunching,
                willEnterForeground: willEnterForeground,
                didBecomeActive: didBecomeActive
            )
        )
    }

    /// Tracks one lifecycle snapshot captured by a hybrid integration before SDK installation.
    ///
    /// Repeated snapshots are treated as conflicting evidence and suppressed.
    @_spi(SplunkInternal)
    public func track(initialLifecycle snapshot: AppStartLifecycleSnapshot) {
        process(event: .hybridSnapshot(snapshot, receivedAt: Date()))
    }


    // MARK: - Testing support

    var processStartTimestamp: Date? {
        get {
            withLock {
                guard case let .initial(evidence) = state else {
                    return nil
                }

                return evidence.processStart
            }
        }
        set {
            withLock {
                guard case var .initial(evidence) = state else {
                    return
                }

                evidence.processStart = newValue
                state = .initial(evidence)
            }
        }
    }

    var prewarmDetected: Bool {
        get {
            withLock {
                guard case let .initial(evidence) = state else {
                    return false
                }

                return evidence.launchOrigin == .prewarmed
            }
        }
        set {
            withLock {
                guard case var .initial(evidence) = state else {
                    return
                }

                if newValue {
                    evidence.launchOrigin = .prewarmed
                }
                else if evidence.launchOrigin == .prewarmed {
                    evidence.launchOrigin = .unknown
                }

                state = .initial(evidence)
            }
        }
    }

    var suppressionReason: AppStartSuppressionReason? {
        withLock {
            switch state {
            case let .active(resolution),
                let .background(resolution),
                let .foregrounding(resolution, _),
                let .stopped(resolution):
                return resolution.suppressionReason

            case .initial:
                return nil
            }
        }
    }


    // MARK: - Event processing

    func process(event: AppStartReducer.Event) {
        // Direct handoffs use the state lock but do not belong to a notification generation.
        perform(prepare(event: event))
    }

    func prepare(event: AppStartReducer.Event) -> ProcessingOutput {
        withLock { () -> ProcessingOutput in
            let result = AppStartReducer.reduce(state: state, event: event)
            state = result.state

            guard let action = result.action else {
                return (nil, nil)
            }

            switch action {
            case let .send(appStart) where appStart.type == .cold:
                let initialize = agentInitializeSpanData.flatMap {
                    Self.containedAgentInitialize($0, in: appStart)
                }
                agentInitializeSpanData = nil
                return (action, initialize)

            case let .send(appStart) where appStart.type == .warm:
                // Agent initialization is attached only to an uninterrupted cold start.
                agentInitializeSpanData = nil
                return (action, nil)

            case .suppress:
                agentInitializeSpanData = nil
                return (action, nil)

            case .send:
                return (action, nil)
            }
        }
    }

    func perform(_ output: ProcessingOutput) {
        perform(action: output.action, agentInitialize: output.agentInitialize)
    }

    private func perform(
        action: AppStartReducer.Action?,
        agentInitialize: AgentInitializeSpanData?
    ) {
        guard let action else {
            return
        }

        switch action {
        case let .send(appStart):
            destination.send(
                appStart: appStart,
                agentInitialize: agentInitialize,
                sharedState: sharedState
            )

            logger.log(level: .debug) {
                "AppStart emitted. type=\(appStart.type.rawValue) start=\(appStart.start) end=\(appStart.end)"
            }

        case let .suppress(reason):
            logger.log(level: .warn) {
                "AppStart measurement suppressed. reason=\(reason.rawValue)"
            }
        }
    }

    private func withLock<Result>(_ work: () -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }

    private static func containedAgentInitialize(
        _ initialize: AgentInitializeSpanData,
        in appStart: AppStartSpanData
    ) -> AgentInitializeSpanData? {
        guard AppStartReducer.valid(initialize.start),
            AppStartReducer.valid(initialize.end),
            appStart.start <= initialize.start,
            initialize.start <= initialize.end,
            initialize.end <= appStart.end,
            (initialize.events ?? [])
                .allSatisfy({ event in
                    AppStartReducer.valid(event.timestamp)
                        && initialize.start <= event.timestamp
                        && event.timestamp <= initialize.end
                })
        else {
            return nil
        }

        return initialize
    }
}
