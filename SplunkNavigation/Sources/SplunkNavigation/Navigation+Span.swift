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
internal import OpenTelemetryApi

extension Navigation {

    // MARK: - Static constants

    private static let component = "ui"
    private static let componentKey = "component"

    static let defaultScreenName = "unknown"

    private static let screenNameKey = "screen.name"
    private static let lastScreenNameKey = "last.screen.name"

    private static let objectTypeKey = "object.type"


    // MARK: - Private

    private var tracer: Tracer {
        OpenTelemetry
            .instance
            .tracerProvider
            .get(
                instrumentationName: "splunk-navigation-detection",
                instrumentationVersion: appBundleName
            )
    }


    // MARK: - Span creation

    func send(navigation: NavigationPair) {
        let spanName = spanName(for: navigation.type)

        // A new navigation span describing the period when the controller was displayed
        let navigationSpan = tracer
            .spanBuilder(spanName: spanName)
            .setStartTime(time: navigation.start)
            .startSpan()

        navigationSpan.setAttribute(key: Self.componentKey, value: nil)
        navigationSpan.setAttribute(key: Self.componentKey, value: Self.component)

        let screenName = navigation.screenName
        navigationSpan.setAttribute(key: Self.lastScreenNameKey, value: nil)
        navigationSpan.setAttribute(key: Self.lastScreenNameKey, value: screenName)
        navigationSpan.setAttribute(key: Self.screenNameKey, value: nil)
        navigationSpan.setAttribute(key: Self.screenNameKey, value: screenName)

        let navigationEnd = navigation.end ?? Date()
        navigationSpan.end(time: navigationEnd)
    }

    func send(screenName: String, lastScreenName: String, start: Date) {
        // A new zero length span for change screen name event
        let screenNameSpan = tracer
            .spanBuilder(spanName: "screen name change")
            .setStartTime(time: start)
            .startSpan()

        screenNameSpan.setAttribute(key: Self.componentKey, value: nil)
        screenNameSpan.setAttribute(key: Self.componentKey, value: Self.component)
        screenNameSpan.setAttribute(key: Self.lastScreenNameKey, value: nil)
        screenNameSpan.setAttribute(key: Self.lastScreenNameKey, value: lastScreenName)
        screenNameSpan.setAttribute(key: Self.screenNameKey, value: nil)
        screenNameSpan.setAttribute(key: Self.screenNameKey, value: screenName)

        screenNameSpan.end(time: start)
    }


    // MARK: - Private methods

    private func spanName(for navigationType: NavigationType) -> String {
        switch navigationType {
        case .show:
            return "ShowVC"

        case .transition:
            return "PresentationTransition"
        }
    }
}
