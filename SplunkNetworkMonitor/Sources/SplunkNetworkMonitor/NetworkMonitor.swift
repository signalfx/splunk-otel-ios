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
internal import OpenTelemetryApi
import SplunkCommon

// MARK: - Public

/// Represents the type of network connection available to the device.
public enum ConnectionType: String {
    case wifi
    case cellular
    case wiredEthernet
    case vpn
    case other
    case unavailable
}

public class NetworkMonitor {

    /// An instance of the Agent shared state object, which is used to obtain agent's state, e.g. a session id.
    public unowned var sharedState: AgentSharedState?

    /// Shared instance of NetworkMonitor for singleton access.
    public static let shared = NetworkMonitor()

    /// An optional callback for network changes
    public var statusChangeHandler: ((Bool, ConnectionType, String?) -> Void)?

    // MARK: - Private

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")

    private var networkChangeEvent = NetworkMonitorEvent(
        timestamp: Date(),
        isConnected: false,
        connectionType: .unavailable,
        radioType: nil
    )
    private var previousChangeEvent = NetworkMonitorEvent(
        timestamp: Date(),
        isConnected: false,
        connectionType: .unavailable,
        radioType: nil
    )
    private var isInitialEvent = true

    private let telephonyInfo = CTTelephonyNetworkInfo()

    private var destination: NetworkMonitorDestination = OTelDestination()

    // MARK: - Initialization

    // Module conformance
    public required init() {}

    deinit {
        stopDetection()
    }

    /// Starts monitoring network connectivity changes.
    ///
    /// ## Important
    ///
    /// Call this method after setting up your `statusChangeHandler` if you want to receive
    /// network change callbacks.
    public func startDetection() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            networkChangeEvent.timestamp = Date()
            networkChangeEvent.isConnected = path.status == .satisfied
            networkChangeEvent.connectionType = self.getConnectionType(path)
            networkChangeEvent.radioType = self.getCurrentRadioAccessTechnology()

            if isInitialEvent {
                isInitialEvent = false
                previousChangeEvent = networkChangeEvent
            } else {
                if networkChangeEvent.isDifferent(from: previousChangeEvent) {
                    sendNetworkChangeSpan()
                }
            }
        }
        monitor.start(queue: queue)

        // Radio Access Technologies detection (connection subtype in Otel)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(radioAccessChanged),
            name: .CTServiceRadioAccessTechnologyDidChange,
            object: nil
        )
    }

    /// Stops monitoring network connectivity changes.
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
        destination.send(networkEvent: networkChangeEvent, sharedState: sharedState)
        self.statusChangeHandler?(
            networkChangeEvent.isConnected,
            networkChangeEvent.connectionType,
            networkChangeEvent.radioType
        )
        previousChangeEvent = networkChangeEvent
    }

    @objc private func radioAccessChanged() {
        isInitialEvent = false
        networkChangeEvent.timestamp = Date()
        networkChangeEvent.radioType = getCurrentRadioAccessTechnology()
        sendNetworkChangeSpan()
    }

    // swiftlint:disable cyclomatic_complexity
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
    // swiftlint:enable cyclomatic_complexity
}
