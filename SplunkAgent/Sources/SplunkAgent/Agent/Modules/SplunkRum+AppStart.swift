//
/*
Copyright 2026 Splunk Inc.

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
@_spi(SplunkInternal) internal import SplunkAppStart
@_spi(SplunkInternal) internal import SplunkAppState
@_spi(SplunkInternal) internal import SplunkCommon

extension SplunkRum {

    /// Reports agent initialization metrics.
    func reportAgentInitialization(start: Date, initializeEvents: [String: Date]) {
        guard let modulesManager else {
            return
        }

        var initializeEvents = initializeEvents

        // Fetch modules initialization times from the Modules manager
        for (moduleName, time) in modulesManager.modulesInitializationTimes {
            let moduleName = "\(moduleName)_initialized"
            initializeEvents[moduleName] = time
        }

        // Report initialize events to App Start module
        if let appStartModule = modulesManager.module(ofType: SplunkAppStart.AppStart.self) {
            appStartModule.reportAgentInitialize(
                start: start,
                end: Date(),
                events: initializeEvents,
                configurationSettings: configurationSettings
            )
            appStartModule.resumeInitialLifecycleResolution()
        }
    }

    private var configurationSettings: [String: String] {
        var settings: [String: String] = [:]

        settings["enableDebugLogging"] = String(agentConfigurationHandler.configuration.enableDebugLogging)
        settings["sessionSamplingRate"] = String(agentConfigurationHandler.configuration.session.samplingRate)

        if let modulesConfigurations = modulesManager?.modulesConfigurationDescription {
            settings.merge(modulesConfigurations) { $1 }
        }

        return settings
    }

    /// Configure App start module with shared state and a public api proxy.
    func customizeAppStart() {
        guard let appStartModule = modulesManager?.module(ofType: SplunkAppStart.AppStart.self) else {
            return
        }

        let customize = { [self, appStartModule] in
            appStartModule.sharedState = sharedState

            // The core recorder owns lifecycle observation. The module's temporary
            // listeners are removed after installation so all consumers use the same
            // first-event-wins snapshot and future updates.
            appStartModule.resetLifecycleObservationState()
            appStartModule.deferInitialLifecycleResolution()
            lifecycleRecorder.addObserver { [weak appStartModule] update in
                appStartModule?
                    .consume(
                        coreLifecycle: update.event,
                        snapshot: Self.appStartLifecycleSnapshot(from: update.snapshot)
                    )
            }

            // Initialize proxy API for this module
            appStartProxy = AppStart(for: appStartModule)
        }

        // AppStart lifecycle state and notification callbacks are main-thread state.
        // Keep reset, deferral, and recorder subscription as one ordered transition
        // when the agent is installed from a hybrid/background thread.
        if Thread.isMainThread {
            customize()
        }
        else {
            DispatchQueue.main.sync(execute: customize)
        }
    }

    /// Configure App state module with shared state.
    func customizeAppState() {
        let appStateModule = modulesManager?.module(ofType: SplunkAppState.AppStateModule.self)

        let customize = { [self, appStateModule] in
            // Local observers are removed before the recorder observer is
            // registered. Keep that transition on main so no UIKit lifecycle
            // callback can fall into the handoff gap.
            appStateModule?.sharedState = sharedState
            appStateModule?.use(lifecycleRecorder: lifecycleRecorder)
        }

        if Thread.isMainThread {
            customize()
        }
        else {
            DispatchQueue.main.sync(execute: customize)
        }
    }

    private static func appStartLifecycleSnapshot(
        from snapshot: AppLifecycleRecorder.Snapshot
    ) -> SplunkAppStart.AppStartLifecycleSnapshot {
        let launchOrigin: SplunkAppStart.AppStartLifecycleSnapshot.LaunchOrigin

        switch snapshot.launchOrigin {
        case .foreground:
            launchOrigin = .foreground

        case .background:
            launchOrigin = .background

        case .unknown:
            launchOrigin = .unknown
        }

        return SplunkAppStart.AppStartLifecycleSnapshot(
            launchOrigin: launchOrigin,
            launchOriginConfidence: snapshot.launchOriginConfidence,
            didFinishLaunching: snapshot.didFinishLaunching,
            willEnterForeground: snapshot.willEnterForeground,
            didBecomeActive: snapshot.didBecomeActive,
            recorderStartedAt: snapshot.recorderStartedAt,
            prewarmDetected: snapshot.prewarmDetected,
            events: snapshot.events
        )
    }
}
