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

#if canImport(WebKit)

    import Foundation
    import WebKit
    import XCTest

    @testable import SplunkAgent
    @testable import SplunkWebView

    /// The `WebView` proxy forwards session changes to the WebView module, which pushes the new session into
    /// instrumented web views.
    ///
    /// The proxy tests post on a private center, so agents left by other tests do not react to them.
    @MainActor
    final class WebViewProxySessionTests: XCTestCase {

        // MARK: - Static constants

        private static let firstSessionId = "0123456789abcdef0123456789abcdef"
        private static let secondSessionId = "fedcba9876543210fedcba9876543210"


        // MARK: - Proxy

        func testSessionResetPushesNewSession() {
            let sharedState = MockAgentSharedState(sessionId: Self.firstSessionId)
            let notificationCenter = NotificationCenter()
            let proxy = WebView(module: WebViewInstrumentation(), sharedState: sharedState, notificationCenter: notificationCenter)
            let webView = MockWKWebView()
            proxy.integrateWithBrowserRum(webView)
            let evaluatedBefore = webView.evaluatedJavaScripts.count

            sharedState.updateSessionId(Self.secondSessionId)
            notificationCenter.post(name: Session.sessionDidResetNotification, object: Self.secondSessionId)

            XCTAssertEqual(webView.evaluatedJavaScripts.count, evaluatedBefore + 1)
            XCTAssertTrue(webView.evaluatedJavaScripts.last?.contains("'\(Self.secondSessionId)'") ?? false)
            withExtendedLifetime(proxy) {}
        }

        func testReleasedProxyStopsForwarding() {
            let sharedState = MockAgentSharedState(sessionId: Self.firstSessionId)
            let notificationCenter = NotificationCenter()
            let module = WebViewInstrumentation()
            let webView = MockWKWebView()

            autoreleasepool {
                let proxy = WebView(module: module, sharedState: sharedState, notificationCenter: notificationCenter)
                proxy.integrateWithBrowserRum(webView)
            }
            let evaluatedBefore = webView.evaluatedJavaScripts.count

            sharedState.updateSessionId(Self.secondSessionId)
            notificationCenter.post(name: Session.sessionDidResetNotification, object: Self.secondSessionId)

            XCTAssertEqual(webView.evaluatedJavaScripts.count, evaluatedBefore)
            withExtendedLifetime(module) {}
        }


        // MARK: - Installed agent

        /// The proxy the agent builds hears the rotation of the agent's own session.
        func testInstalledAgentPushesRotatedSession() throws {
            restoreOpenTelemetryGlobalsAtTeardown()

            let session = DefaultSession(
                sessionsModel: SessionsModel(storage: UserDefaultsStorageTestBuilder.buildCleanStorage(named: UUID().uuidString))
            )
            let agent = try AgentTestBuilder.build(with: ConfigurationTestBuilder.buildDefault(), session: session)
            stopAtTeardown(agent)
            agent.modulesManager = DefaultModulesManager(
                rawConfiguration: nil,
                moduleConfigurations: [],
                for: WebViewTestModulesPool.self
            )
            agent.customizeModules()

            let webView = MockWKWebView()
            agent.webViewNativeBridge.integrateWithBrowserRum(webView)
            let firstSessionId = session.currentSessionId
            let evaluatedBefore = webView.evaluatedJavaScripts.count

            session.rotateSession()

            let secondSessionId = session.currentSessionId
            XCTAssertNotEqual(secondSessionId, firstSessionId)
            XCTAssertGreaterThan(webView.evaluatedJavaScripts.count, evaluatedBefore)
            XCTAssertTrue(webView.evaluatedJavaScripts.last?.contains("'\(secondSessionId)'") ?? false)
        }
    }

#endif
