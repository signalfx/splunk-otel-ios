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
@_implementationOnly import SplunkLogger

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#endif

/// The object implements the management of the current session.
class DefaultSession: AgentSession {

    // MARK: - Private

    // Serializes external access to stored data
    private let accessQueue: DispatchQueue

    var refreshJob: RepeatingJob?

    private var sessionsModel: SessionsModel
    private(set) lazy var currentSession: SessionItem = resumeSession()

    private var enterBackground: Date?
    private var leaveBackground: Date?

    private let internalLogger = InternalLogger(configuration: .agent(category: "Session Management"))


    // MARK: - Test support

    var testSessionTimeout: Double?


    // MARK: - Public

    /// The agent instance to which the session belongs.
    public unowned var owner: SplunkRum?

    /// Defines the minimum session refresh interval (defined in seconds). Default value is 1 second.
    public var sessionRefreshInterval: Double = 1

    /// Session inactivity timeout (defined in seconds). Default value is 15 minutes.
    public var sessionTimeout: Double {
        let unitTest = testSessionTimeout
        let configuration = owner?.agentConfiguration.sessionTimeout
        let defaultValue = ConfigurationDefaults.sessionTimeout

        return unitTest ?? configuration ?? defaultValue
    }

    /// The maximal length of one session (defined in seconds). Default value is 1 hour.
    public var maxSessionLength: Double {
        let configuration = owner?.agentConfiguration.maxSessionLength
        let defaultValue = ConfigurationDefaults.maxSessionLength

        return configuration ?? defaultValue
    }


    // MARK: - Computed properties

    public var currentSessionId: String {
        accessQueue.sync {
            currentSession.id
        }
    }

    public var currentSessionItem: SessionItem {
        accessQueue.sync {
            currentSession
        }
    }


    // MARK: - Initialization

    required init(sessionsModel: SessionsModel = SessionsModel()) {
        self.sessionsModel = sessionsModel

        let queueName = PackageIdentifier.default(named: "sessionAccess")
        accessQueue = DispatchQueue(label: queueName)

        // Initiates session resuming process
        _ = currentSessionId

        // Starts observing for application lifecycle
        hookToAppLifecycle()

        // Start a perpetual check of the session state
        refreshJob = RepeatingJob(interval: sessionRefreshInterval, block: { [weak self] in
            // We constantly check the situation.
            // If the current state requires it, we create a new session.
            self?.refreshSession()
        }).resume()

        // Set up the session immediately
        refreshSession()
    }

    deinit {
        refreshJob?.suspend()
        refreshJob = nil
    }


    // MARK: - Sessions identification

    func sessionId(for timestamp: Date) -> String? {
        accessQueue.sync {
            session(for: timestamp)?.id
        }
    }

    private func session(for timestamp: Date) -> SessionItem? {
        // The individual records should follow each other by time,
        // but we won't rely on that for this case.
        let sorted = sessionsModel.sessions
            .sorted { first, second in
                first.start > second.start
            }

        // Corresponding session candidate
        let session = sorted.first { item in
            item.start < timestamp
        }

        // Verify that the session falls within the limits
        // defined by the configurations
        if
            let session,
            session.start + maxSessionLength + sessionRefreshInterval + (refreshJob?.tolerance ?? 0.0) > timestamp
        {
            return session
        }

        return nil
    }


    // MARK: - Business logic

    // TODO: MRUM_AC-1457 (post GA): Reimplement session rotation after an app relaunch
    /// ⚠️⚠️⚠️ This method currently forces a session rotation. This method in this current form should be called only once
    /// when the Agent initializes. This method needs reimplementation.
    func resumeSession() -> SessionItem {
        // Before restoring the session,
        // we need to delete the outdated data
        sessionsModel.purge()

        // Close previous session
        if
            var previousSession = sessionsModel.sessions.last,
            !(previousSession.closed ?? false)
        {
            previousSession.closed = true

            // Updates corresponding item in `SessionsModel`
            let previousSessionIndex = sessionsModel.sessions.firstIndex { item in
                item.id == previousSession.id
            }

            if let previousSessionIndex {
                sessionsModel.sessions[previousSessionIndex] = previousSession
            }

            internalLogger.log(level: .info) {
                "Previous session (id \(previousSession.id)) has been closed."
            }
        }

        // Create a new session and save changes.
        let newSession = createSession()
        sessionsModel.sync()

        return newSession
    }

    func refreshSession() {
        // Exceeding the limit for running in the background
        if isInBackgroundTooLong() {
            internalLogger.log(level: .info) {
                "Current session length exceeded the length limit for running in background."
            }

            enterBackground = nil
            leaveBackground = nil
            rotateSession()

            return
        }

        // Exceeding the limit for the length of one session
        if isSessionTooLong() {
            internalLogger.log(level: .info) {
                "Current session length exceeded the length limit."
            }

            rotateSession()

            return
        }
    }

    func rotateSession() {
        // We will announce our intention to close the session
        NotificationCenter.default.post(
            name: Self.sessionWillResetNotification,
            object: currentSessionId
        )

        // Performs the closing of the existing session and creates a fresh new one
        closeSession()
        currentSession = createSession()

        // Save changes into cache
        sessionsModel.sync()

        // We will announce that the session closing is done
        NotificationCenter.default.post(
            name: Self.sessionDidResetNotification,
            object: currentSessionId
        )
    }

    func createSession() -> SessionItem {
        let newSession = SessionItem(
            id: String.uniqueIdentifier(),
            start: Date()
        )

        // Adds new session item into `SessionsModel`
        sessionsModel.sessions.append(newSession)

        internalLogger.log(level: .info) {
            "New session with id \(newSession.id) has been created."
        }

        return newSession
    }

    func closeSession() {
        currentSession.closed = true

        // Updates corresponding item in `SessionsModel`
        let currentSessionIndex = sessionsModel.sessions.firstIndex { item in
            item.id == currentSession.id
        }

        if let currentSessionIndex {
            sessionsModel.sessions[currentSessionIndex] = currentSession
        }

        internalLogger.log(level: .info) { [weak self] in
            guard let sessionId = self?.currentSession.id else {
                return "Current session has been closed."
            }

            return "Current session (id \(sessionId)) has been closed."
        }
    }

    func endSession() {
        closeSession()

        // Save changes into cache
        sessionsModel.sync()
    }


    // MARK: - Length checks

    private func isSessionTooLong() -> Bool {
        let sessionLength = -1.0 * currentSession.start.timeIntervalSinceNow
        let isTooLong = sessionLength > maxSessionLength

        return isTooLong
    }

    private func isInBackgroundTooLong() -> Bool {
        guard
            let enterBackground,
            let leaveBackground
        else {
            return false
        }

        let timeInBackground = leaveBackground.timeIntervalSince(enterBackground)
        let isTooLong = timeInBackground > sessionTimeout

        return isTooLong
    }
}


extension DefaultSession {

    // MARK: - Application lifecycle

    private func hookToAppLifecycle() {
        #if os(iOS) || os(tvOS) || os(visionOS)

            // Transitioning an application to the background
            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                // We need to mark the time of this transition
                self?.enterBackground = Date()
            }

            // Transitioning an application to the foreground
            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                // We need to mark the time of this transition
                if self?.enterBackground != nil {
                    self?.leaveBackground = Date()
                }
            }

            // The application is being terminated
            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in

                // We need to end current session
                self?.endSession()
            }

        #endif
    }
}
