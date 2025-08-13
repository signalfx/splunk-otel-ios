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
internal import SplunkCommon

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#endif

// The object implements the management of the current session
class DefaultSession: AgentSession {

    // MARK: - Private

    /// Serializes external access to stored data.
    private let accessQueue: DispatchQueue

    var refreshJob: RepeatingJob?

    private var sessionsModel: SessionsModel
    private(set) lazy var currentSession: SessionItem = startSession()

    private var enterBackground: Date?
    private var leaveBackground: Date?

    private let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "Agent")


    // MARK: - Test support

    var testSessionTimeout: Double?
    var testMaxSessionLength: Double?


    // MARK: - Internal

    /// The ``SplunkRum`` agent instance to which the session belongs.
    unowned var owner: SplunkRum?

    /// Defines the minimum session refresh interval (defined in seconds). Default value is 1 second.
    var sessionRefreshInterval: Double = 1

    /// Session inactivity timeout (defined in seconds). Default value is 15 minutes.
    var sessionTimeout: Double {
        let unitTest = testSessionTimeout
        let configuration = owner?.agentConfiguration.sessionTimeout
        let defaultValue = ConfigurationDefaults.sessionTimeout

        return unitTest ?? configuration ?? defaultValue
    }

    /// The maximal length of one session (defined in seconds). Default value is 1 hour.
    var maxSessionLength: Double {
        let unitTest = testMaxSessionLength
        let configuration = owner?.agentConfiguration.maxSessionLength
        let defaultValue = ConfigurationDefaults.maxSessionLength

        return unitTest ?? configuration ?? defaultValue
    }


    // MARK: - Computed properties

    /// The current session identifier.
    var currentSessionId: String {
        accessQueue.sync {
            currentSession.id
        }
    }

    /// The current ``SessionItem`` representing the session's state.
    var currentSessionItem: SessionItem {
        accessQueue.sync {
            currentSession
        }
    }


    // MARK: - Initialization

    /// Initializes a new session instance.
    ///
    /// - Parameter sessionsModel: The `SessionsModel` instance to manage session data.
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
            // We constantly check the situation
            // If the current state requires it, we create a new session
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
        // but we won't rely on that for this case
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
            session.start + maxSessionLength + sessionRefreshInterval + (refreshJob?.tolerance ?? 0.0) > timestamp {
            return session
        }

        return nil
    }


    // MARK: - Business logic

    /// Starts a new session by first purging old data, closing previous session and then starting a new session.
    func startSession() -> SessionItem {
        // Before restoring the session,
        // we need to delete the outdated data
        sessionsModel.purge()

        // Close previous session
        if
            var previousSession = sessionsModel.sessions.last,
            !(previousSession.closed ?? false) {
            previousSession.closed = true

            // Updates corresponding item in `SessionsModel`
            let previousSessionIndex = sessionsModel.sessions.firstIndex { item in
                item.id == previousSession.id
            }

            if let previousSessionIndex {
                sessionsModel.sessions[previousSessionIndex] = previousSession
            }

            let previousSessionId = previousSession.id

            logger.log(level: .info) {
                "Previous session (id \(previousSessionId)) has been closed."
            }
        }

        // Create a new session and save changes
        let newSession = createSession()
        sessionsModel.sync()

        return newSession
    }

    func refreshSession() {
        // Exceeding the limit for running in the background
        if isInBackgroundTooLong() {
            logger.log(level: .info) {
                "Current session length exceeded the length limit for running in background."
            }

            enterBackground = nil
            leaveBackground = nil
            rotateSession()

            return
        }

        // Exceeding the limit for the length of one session
        if isSessionTooLong() {
            logger.log(level: .info) {
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
            id: String.uniqueHexIdentifier(ofLength: 32),
            start: Date()
        )

        // Adds new session item into `SessionsModel`
        sessionsModel.sessions.append(newSession)

        logger.log(level: .info) {
            "New session with id \(newSession.id) has been created."
        }

        return newSession
    }

    func closeSession() {
        currentSession.closed = true

        let currentSessionId = currentSession.id

        // Updates corresponding item in `SessionsModel`
        let currentSessionIndex = sessionsModel.sessions.firstIndex { item in
            item.id == currentSessionId
        }

        if let currentSessionIndex {
            sessionsModel.sessions[currentSessionIndex] = currentSession
        }

        logger.log(level: .info) {
            "Current session (id \(currentSessionId)) has been closed."
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

                    // Refresh session immediately
                    self?.refreshSession()
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
