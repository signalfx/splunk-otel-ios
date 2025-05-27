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

public class NetworkInfo {
    public enum ConnectionType: String {
        case wifi
        case cellular
        case wiredEthernet
        case other
        case lost
    }

    public static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    private var tracer: Tracer

    public private(set) var isConnected: Bool = false
    public private(set) var connectionType: ConnectionType = .lost
    public private(set) var isVPNActive: Bool = false

    public var statusChangeHandler: ((Bool, ConnectionType, Bool) -> Void)?

    // MARK: - Initialization

    // Module conformance
    public required init() {}

    public func startDetection() {
        self.tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "NetworkMonitor", instrumentationVersion: "1.0")

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.isConnected = path.status == .satisfied
            self.connectionType = self.getConnectionType(path)
            self.isVPNActive = path.availableInterfaces.contains(where: { iface in
                iface.type == .other &&
                (iface.name.lowercased().contains("utun") ||
                 iface.name.lowercased().contains("ppp") ||
                 iface.name.lowercased().contains("ipsec"))
            })
            self.sendNetworkChangeSpan()
            self.statusChangeHandler?(self.isConnected, self.connectionType, self.isVPNActive)
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
            return .other
        }
    }

    private func sendNetworkChangeSpan() {
        let span = tracer.spanBuilder(spanName: "network.change").startSpan()
        span.setAttribute(key: "network.connected", value: isConnected)
        span.setAttribute(key: "network.connection.type", value: connectionType.rawValue)
        span.setAttribute(key: "network.vpn", value: isVPNActive)
        span.end()
    }
}
