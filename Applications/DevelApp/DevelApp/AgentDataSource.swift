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

import Combine
import SplunkAgent
import SwiftUI

class AgentDataSource: ObservableObject {

    // MARK: - Published Properties

    @Published var agentVersion: String = SplunkRum.version
    @Published var agentAppVersion: String = SplunkRum.instance.state.appVersion
    @Published var sessionId: String = SplunkRum.instance.session.state.id
    @Published private var userTrackingMode = SplunkRum.instance.user.state.trackingMode
    @Published var rumEnabled: Bool = SplunkRum.instance.state.status == .running

    // MARK: - Session publisher for handling session resets

    private let sessionPublisher = NotificationCenter.default
        .publisher(for: NSNotification.Name("com.splunk.rum.session-did-reset"))
        .receive(on: DispatchQueue.main)

    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Initialization

    init() {
        // Observe session reset notifications
        sessionPublisher
            .sink { [weak self] output in
                if let currentSessionId = output.object as? String {
                    withAnimation {
                        self?.sessionId = currentSessionId
                    }
                }
            }
            .store(in: &cancellables)

        // Observe changes to agent status (rumEnabled) based on `state.status`
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.rumEnabled = (SplunkRum.instance.state.status == .running)
                self?.sessionId = SplunkRum.instance.session.state.id
                self?.userTrackingMode = SplunkRum.instance.user.state.trackingMode
            }
        }
    }

    // MARK: - Derived Properties

    var agentStatusDescription: String {
        return rumEnabled ? "Running" : "Not Running"
    }
}
