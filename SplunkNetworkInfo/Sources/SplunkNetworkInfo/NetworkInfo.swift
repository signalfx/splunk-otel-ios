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
import Network
import SplunkCommon
import OpenTelemetryApi

public class NetworkInfo {
    public enum ConnectionType: String {
        case wifi
        case cellular
        case wiredEthernet
        case vpn
        case other
        case lost
    }

    /// An instance of the Agent shared state object, which is used to obtain agent's state, e.g. a session id.
    public unowned var sharedState: AgentSharedState?

    public static let shared = NetworkInfo()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")

    public private(set) var isConnected: Bool = false
    public private(set) var connectionType: ConnectionType = .lost

    public var statusChangeHandler: ((Bool, ConnectionType) -> Void)?

    // MARK: - Initialization

    // Module conformance
    public required init() { }

    public func startDetection() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.isConnected = path.status == .satisfied
            self.connectionType = self.getConnectionType(path)
            self.sendNetworkChangeSpan()
            self.statusChangeHandler?(self.isConnected, self.connectionType)
        }
        monitor.start(queue: queue)
        // Send initial state span
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.sendNetworkChangeSpan()
        }
    }

    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else if path.status == .unsatisfied {
            return .lost
        } else {
            // Check for VPN
            let isVPN = path.availableInterfaces.contains(where: { iface in
                iface.type == .other &&
                (iface.name.lowercased().contains("utun") ||
                 iface.name.lowercased().contains("ppp") ||
                 iface.name.lowercased().contains("ipsec"))
            })
            return isVPN ? .vpn : .other
        }
    }

    private func sendNetworkChangeSpan() {
        let tracer = OpenTelemetry.instance
            .tracerProvider
            .get(
                instrumentationName: "NetworkInfo",
                instrumentationVersion: sharedState?.agentVersion
            )

        let span = tracer.spanBuilder(spanName: "network.change")
                .setStartTime(time: Date())
                .startSpan()
        span.setAttribute(key: "network.status", value: isConnected ? "available" : "lost")
        span.setAttribute(key: "network.connection.type", value: connectionType.rawValue)
        span.end(time: Date())
    }
}
