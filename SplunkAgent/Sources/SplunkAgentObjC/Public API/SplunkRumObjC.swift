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

import Foundation
@_spi(objc) import SplunkAgent

/// The class implementing Splunk Agent public API for Objective-C.
@objc(SPLKAgent)
public final class SplunkRumObjC: NSObject {

    // MARK: - Internal

    var agent: SplunkRum = .shared


    // MARK: - Agent singleton

    /// A singleton shared instance of the Agent library.
    /// This shared instance is used to access all SDK functions.
    @objc
    public private(set) static var shared: SplunkRumObjC = .init()


    // MARK: - Public API

    /// An object that holds current user.
    @objc
    public private(set) lazy var user = UserObjC(for: self)

    /// An object that holds current manages associated session.
    @objc
    public private(set) lazy var session = SessionObjC(for: self)

    // TODO: Solve this logic later!
    /// A dictionary that contains global attributes added to all signals.
    @objc
    public private(set) lazy var globalAttributes: NSMutableDictionary = [:]

    /// An object reflects the current state and setting used for the recording.
    @objc
    public private(set) lazy var state = RuntimeStateObjC(for: self)


    // MARK: - Public API (Modules)


    /// An object that holds Session Replay module.
    @objc
    public private(set) lazy var sessionReplay = SessionReplayModuleObjC(for: self)

    /// An object that holds Custom Tracking  module.
    @objc
    public private(set) lazy var customTracking = CustomTrackingModuleObjC(for: self)

    /// An object that holds Navigation module.
    @objc
    public private(set) lazy var navigation = NavigationModuleObjC(for: self)

    /// An object that holds SlowFrameDetector module.
    @objc
    public private(set) lazy var slowFrameDetector = SlowFrameDetectorModuleObjC(for: self)

    /// An object that provides a bridge for WebView instrumentation.
    @objc
    public private(set) lazy var webViewNativeBridge = WebViewModuleObjC(for: self)


    // MARK: - Initialization

    override init() {}

    init(with agent: SplunkRum) {
        self.agent = agent
    }


    // MARK: - Agent builder

    /// Creates and initializes the singleton instance.
    ///
    /// Emits error from `SplunkRum.AgentConfigurationError` if the provided configuration is invalid.
    ///
    /// - Parameters:
    ///   - configuration: A configuration for the initial SDK setup.
    @objc
    public static func install(with configuration: AgentConfigurationObjC) throws -> SplunkRumObjC {
        // Create an agent instance or emit errors
        let agentConfiguration = configuration.agentConfiguration()
        let agent = try SplunkRum.install(with: agentConfiguration)

        // Use the installed agent in this Objective-C bridge
        shared = SplunkRumObjC(with: agent)

        return shared
    }


    // MARK: - Version

    /// A version of this agent.
    @objc
    public static var agentVersion: String {
        SplunkRum.version
    }
}
