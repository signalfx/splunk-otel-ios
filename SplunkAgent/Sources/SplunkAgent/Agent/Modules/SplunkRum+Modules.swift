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

internal import CiscoSessionReplay
import Foundation
internal import SplunkAppStart
internal import SplunkAppState
internal import SplunkCustomTracking
internal import SplunkInteractions
@_spi(SplunkInternal) internal import SplunkNavigation
internal import SplunkNetwork
internal import SplunkNetworkMonitor
internal import SplunkSessionReplayProxy
internal import SplunkSlowFrameDetector
internal import SplunkWebView

#if canImport(SplunkCrashReports)
    internal import SplunkCrashReports
#endif

#if canImport(WebKit)
    import WebKit
#endif


extension SplunkRum {

    // MARK: - Modules publish

    func registerModulePublish() {
        // Send events on data publish
        modulesManager?
            .onModulePublish(data: { metadata, data in
                self.eventManager?
                    .publish(data: data, metadata: metadata) { success in
                        if success {
                            self.modulesManager?.deleteModuleData(for: metadata)
                        }
                    }
            })
    }


    // MARK: - Modules customization

    /// Perform specific pre-defined customizations for some modules.
    func customizeModules() {
        customizeCrashReports()
        customizeSessionReplay()
        customizeNavigation()
        customizeNetwork()
        customizeAppStart()
        customizeAppState()
        customizeNetworkMonitor()
        customizeCustomTracking()
        customizeInteractions()
        customizeWebView()
        customizeSlowFrameDetector()
    }

    // MARK: - Session Replay

    /// Evaluates Session Replay configuration and sampling, then sets the appropriate proxy.
    ///
    /// The proxy is always created based on config/sampling — endpoint availability
    /// does not gate this decision. When the endpoint is deferred, the underlying
    /// exporter caches replay chunks to disk and flushes them once an endpoint is
    /// provided via ``updateEndpoint(_:)``.
    private func customizeSessionReplay() {
        let moduleType = CiscoSessionReplay.SessionReplay.self
        guard let sessionReplayModule = modulesManager?.module(ofType: moduleType) else {
            logger.log(level: .warn, isPrivate: false) {
                "Session Replay module was not found in the modules manager."
            }

            return
        }

        sessionReplayDecisionMade = true

        let config = moduleConfigurations?.compactMap { $0 as? SessionReplayConfiguration }.first ?? SessionReplayConfiguration()
        let effectiveSamplingRate = resolvedSamplingRate(from: config)

        guard config.enabled else {
            logger.log(level: .notice, isPrivate: false) {
                "Session Replay module is disabled by configuration."
            }

            sessionReplayProxy = SessionReplayNonOperational(
                statusCause: .notStarted,
                samplingRate: effectiveSamplingRate
            )

            return
        }

        let sampler = SessionReplaySampler(probability: effectiveSamplingRate)
        if sampler.sample() == .sampledOut {
            logger.log(level: .notice, isPrivate: false) {
                "Session Replay module disabled by sampling (rate: \(effectiveSamplingRate))."
            }

            sessionReplayProxy = SessionReplayNonOperational(
                statusCause: .disabledBySampling,
                samplingRate: effectiveSamplingRate
            )

            return
        }

        #if canImport(WebKit)
            sessionReplayModule.sensitivity.set(WKWebView.self, nil)
        #endif

        sessionReplayProxy = SessionReplay(for: sessionReplayModule, samplingRate: effectiveSamplingRate)
    }

    private func resolvedSamplingRate(from config: SessionReplayConfiguration) -> Double {
        let configured = config.samplingRate ?? 1.0
        let sanitized = configured.isFinite ? configured : 1.0
        let effective = min(max(sanitized, 0.0), 1.0)
        if !configured.isFinite || configured < 0.0 || configured > 1.0 {
            logger.log(level: .warn, isPrivate: false) {
                """
                Session Replay sampling rate \(configured) is outside the valid \
                range <0, 1>. The value has been clamped to \(effective).
                """
            }
        }
        return effective
    }


    // MARK: - Network

    /// Configure Network module with shared state.
    private func customizeNetwork() {
        let networkModule = modulesManager?.module(ofType: SplunkNetwork.NetworkInstrumentation.self)

        // Assign an object providing the current state of the agent instance.
        // We need to do this because we need to read `sessionId` from the agent continuously.
        networkModule?.sharedState = sharedState

        // Set initial excluded endpoints based on current configuration
        updateNetworkExclusionList(for: agentConfiguration.endpoint)
    }

    /// Updates the network module's excluded endpoints list based on the provided endpoint configuration.
    ///
    /// This method should be called whenever the endpoint configuration changes to ensure
    /// that collector URLs are properly excluded from network instrumentation, preventing
    /// self-instrumentation of export requests.
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint configuration to extract exclusion URLs from, or `nil` to clear exclusions.
    ///   - additionalUrls: Additional URLs to exclude (e.g., caching URLs when endpoint is disabled).
    func updateNetworkExclusionList(for endpoint: EndpointConfiguration?, additionalUrls: [URL] = []) {
        let networkModule = modulesManager?.module(ofType: SplunkNetwork.NetworkInstrumentation.self)

        // Build excluded endpoints list
        var excludedEndpoints: [URL] = additionalUrls

        if let endpoint {
            if let traceUrl = endpoint.traceEndpoint {
                excludedEndpoints.append(traceUrl)
            }

            if let sessionReplayUrl = endpoint.sessionReplayEndpoint {
                excludedEndpoints.append(sessionReplayUrl)
            }
        }

        networkModule?.excludedEndpoints = excludedEndpoints.isEmpty ? nil : excludedEndpoints
    }


    // MARK: - Other Modules

    /// Configure Navigation module.
    private func customizeNavigation() {
        let moduleType = SplunkNavigation.Navigation.self
        let navigationModule = modulesManager?.module(ofType: moduleType)

        guard let navigationModule else {
            return
        }

        #if canImport(SplunkCrashReports)
            let crashReportsModule = modulesManager?.module(ofType: SplunkCrashReports.CrashReports.self)
        #endif

        navigationModule.sharedState = sharedState

        // Synchronously update runtime screen.name on every screen-name change
        // so spans started immediately afterwards carry the new value.
        navigationModule.setScreenNameObserver { [runtimeAttributes] newValue in
            runtimeAttributes.updateScreenName(newValue)
        }

        // Async fanout: public callback and crash-report propagation.
        let screenNameStream = navigationModule.screenNameStream
        Task(priority: .userInitiated) {
            for await newValue in screenNameStream {
                screenNameChangeCallback?(newValue)
                #if canImport(SplunkCrashReports)
                    crashReportsModule?.crashReportUpdateScreenName(newValue)
                #endif
            }
        }

        // Initialize proxy API for this module
        navigationProxy = Navigation(for: navigationModule)
    }

    /// Configure Crash Reports module with shared state.
    private func customizeCrashReports() {
        #if canImport(SplunkCrashReports)
            let crashReportsModule = modulesManager?.module(ofType: SplunkCrashReports.CrashReports.self)

            // Assign an object providing the current state of the agent instance.
            // We need to do this because we need to read `appState` from the agent in the instance of a crash.
            crashReportsModule?.sharedState = sharedState

            if let eventManager = eventManager as? DefaultEventManager {
                crashReportsModule?.crashReportPersistenceHandler = { [weak eventManager] emitSpan, completion in
                    guard let eventManager else {
                        completion(false)
                        return
                    }

                    eventManager.concreteTraceProcessor.persistCrashReportSpan(
                        emitting: emitSpan,
                        completion: completion
                    )
                }
            }

            // Check if a crash ended the previous run of the app
            crashReportsModule?.reportCrashIfPresent()
        #endif
    }

    /// Configure App start module with shared state and a public api proxy.
    private func customizeAppStart() {
        if let appStartModule = modulesManager?.module(ofType: SplunkAppStart.AppStart.self) {
            appStartModule.sharedState = sharedState

            // Initialize proxy API for this module
            appStartProxy = AppStart(for: appStartModule)
        }
    }

    /// Configure App state module with shared state.
    private func customizeAppState() {
        let appStateModule = modulesManager?.module(ofType: SplunkAppState.AppStateModule.self)

        appStateModule?.sharedState = sharedState
    }

    /// Configure NetworkMonitor module.
    private func customizeNetworkMonitor() {
        let networkMonitorModule = modulesManager?.module(ofType: SplunkNetworkMonitor.NetworkMonitor.self)

        networkMonitorModule?.sharedState = sharedState
    }

    /// Configure Interactions module.
    private func customizeInteractions() {
        let interactionsModule = modulesManager?.module(ofType: SplunkInteractions.Interactions.self)

        guard let interactionsModule else {
            return
        }

        // Initialize proxy API for this module
        interactions = Interactions(for: interactionsModule)
    }

    /// Configure WebView Instrumentation module with shared state.
    private func customizeWebView() {
        if let webViewInstrumentationModule = modulesManager?.module(ofType: SplunkWebView.WebViewInstrumentation.self) {
            webViewProxy = WebView(module: webViewInstrumentationModule, sharedState: sharedState)
        }
        else {
            logger.log(level: .notice, isPrivate: false) {
                "WebViewInstrumentation module not installed."
            }
        }
    }

    /// Configure CustomTracking intrumentation module.
    private func customizeCustomTracking() {
        if let customTrackingModule = modulesManager?.module(ofType: CustomTrackingInternal.self) {
            // Initialize proxy API for this module
            customTrackingProxy = customTrackingModule.isEnabled ? CustomTracking(for: customTrackingModule) : CustomTrackingNonOperational()
        }
    }

    /// Configure SlowFrameDetector module.
    private func customizeSlowFrameDetector() {
        if let slowFrameDetectorModule = modulesManager?.module(ofType: SplunkSlowFrameDetector.SlowFrameDetector.self) {
            // Initialize proxy API for this module
            slowFrameDetectorProxy = SlowFrameDetector(for: slowFrameDetectorModule)
        }
    }
}
