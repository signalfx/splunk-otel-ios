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

import CoreTelephony
import Foundation
import Network
import OpenTelemetryApi
import SplunkCommon

/// A class that monitors network connectivity changes and reports them as OTel spans.
///
/// This class uses `NWPathMonitor` to detect changes in network status (e.g., connected, disconnected) and
/// connection type (e.g., Wi-Fi, cellular). It also tracks changes in cellular radio access technology.
public class NetworkMonitor {


    // MARK: - Public

    /// An enumeration representing the type of network connection.
    public enum ConnectionType: String {
        /// A Wi-Fi network connection.
        case wifi
        /// A cellular network connection.
        case cellular
        /// A wired Ethernet network connection.
        case wiredEthernet
        /// A Virtual Private Network (VPN) connection.
        case vpn
        /// Any other type of network connection.
        case other
        /// The network connection is unavailable.
        case unavailable
    }

    /// An instance of the Agent shared state object, which is used to obtain agent's state, e.g. a session id.
    public unowned var sharedState: AgentSharedState?

    /// A shared singleton instance of `NetworkMonitor`.
    public static let shared = NetworkMonitor()

    /// A callback that is invoked when the network status or connection type changes.
    ///
    /// The closure receives two arguments: a `Bool` indicating if the network is connected,
    /// and a `ConnectionType` specifying the current connection type.
    public var statusChangeHandler: ((Bool, ConnectionType) -> Void)?


    // MARK: - Private

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    private var previousStatus: String?
    private var previousType: ConnectionType?

    private let telephonyInfo = CTTelephonyNetworkInfo()


    // MARK: - Nested

    /// The current cellular radio access technology (e.g., "LTE (4G)").
    ///
    /// This property is `nil` if the device is not on a cellular network or the technology cannot be determined.
    public private(set) var currentRadioAccessTechnology: String?
    /// A Boolean value indicating whether the device is currently connected to a network.
    public private(set) var isConnected: Bool = false
    /// The current type of network connection.
    public private(set) var connectionType: ConnectionType = .unavailable


    // MARK: - Initialization

    // Module conformance
    /// Initializes a new instance of the `NetworkMonitor`.
    public required init() {}

    deinit {
        stopDetection()
    }

    /// Starts monitoring for network changes.
    ///
    /// This method sets up the `NWPathMonitor` and registers for notifications about changes
    /// in radio access technology. When a change is detected, a `network.change` span is emitted.
    public func startDetection() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.isConnected = path.status == .satisfied
            self.connectionType = self.getConnectionType(path)

            let currentStatus = self.isConnected ? "available" : "lost"

            if let prevStatus = self.previousStatus,
               let prevType = self.previousType,
               currentStatus != prevStatus || self.connectionType != prevType {
                self.sendNetworkChangeSpan()
                self.statusChangeHandler?(self.isConnected, self.connectionType)
            }
            self.previousStatus = currentStatus
            self.previousType = self.connectionType
        }
        monitor.start(queue: queue)

        // Radio Access Technologies detection (connection subtype in Otel)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(radioAccessChanged),
            name: .CTServiceRadioAccessTechnologyDidChange,
            object: nil
        )

        // Initial fetch of radio access technologies
        updateRadioAccessTechnologies()
    }

    /// Stops monitoring for network changes.
    ///
    /// This method cancels the `NWPathMonitor` and unregisters from system notifications.
    public func stopDetection() {
        monitor.cancel()
        monitor.pathUpdateHandler = nil
        NotificationCenter.default.removeObserver(self, name: .CTServiceRadioAccessTechnologyDidChange, object: nil)
    }

    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else if path.status == .unsatisfied {
            return .unavailable
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
                instrumentationName: "NetworkMonitor",
                instrumentationVersion: sharedState?.agentVersion
            )

        // Getting current timestamp to set zero length span as start and end time
        let timestamp = Date()
        let span = tracer.spanBuilder(spanName: "network.change")
            .setStartTime(time: timestamp)
            .startSpan()
        span.setAttribute(key: "network.status", value: isConnected ? "available" : "lost")
        span.setAttribute(key: "network.connection.type", value: connectionType.rawValue)
        if currentRadioAccessTechnology != nil {
            span.setAttribute(key: "network.connection.subtype", value: currentRadioAccessTechnology!)
        }
        span.end(time: timestamp)
    }

    private func updateRadioAccessTechnologies() {
        currentRadioAccessTechnology = getCurrentRadioAccessTechnology()
    }

    @objc private func radioAccessChanged() {
        updateRadioAccessTechnologies()
        sendNetworkChangeSpan()
    }

    private func getCurrentRadioAccessTechnology() -> String? {
        // Pick the first available radio access technology
        let radioTechnology = telephonyInfo.serviceCurrentRadioAccessTechnology?.values.first ?? nil
        switch radioTechnology {
        case CTRadioAccessTechnologyGPRS:
            return "GPRS (2G)"
        case CTRadioAccessTechnologyEdge:
            return "EDGE (2G)"
        case CTRadioAccessTechnologyWCDMA:
            return "WCDMA (3G)"
        case CTRadioAccessTechnologyHSDPA:
            return "HSDPA (3G)"
        case CTRadioAccessTechnologyHSUPA:
            return "HSUPA (3G)"
        case CTRadioAccessTechnologyCDMA1x:
            return "CDMA1x (2G)"
        case CTRadioAccessTechnologyCDMAEVDORev0:
            return "CDMA EV-DO Rev. 0 (3G)"
        case CTRadioAccessTechnologyCDMAEVDORevA:
            return "CDMA EV-DO Rev. A (3G)"
        case CTRadioAccessTechnologyCDMAEVDORevB:
            return "CDMA EV-DO Rev. B (3G)"
        case CTRadioAccessTechnologyeHRPD:
            return "eHRPD (3G)"
        case CTRadioAccessTechnologyLTE:
            return "LTE (4G)"
        case CTRadioAccessTechnologyNRNSA:
            return "NRNSA (5G Non-Standalone)"
        case CTRadioAccessTechnologyNR:
            return "NR (5G Standalone)"
        default:
            return nil
        }
    }
}
