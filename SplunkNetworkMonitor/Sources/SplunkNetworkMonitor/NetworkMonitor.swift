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
internal import OpenTelemetryApi
import SplunkCommon

#if canImport(CoreTelephony)
    import CoreTelephony
#endif


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

    // MARK: - Private

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")

    #if canImport(CoreTelephony)
        private let telephonyInfo = CTTelephonyNetworkInfo()
    #endif

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

    private var destination: NetworkMonitorDestination = OTelDestination()


    // MARK: - Public

    /// An instance of the Agent shared state object, which is used to obtain agent's state, e.g. a session id.
    public unowned var sharedState: AgentSharedState?

    /// Shared instance of NetworkMonitor for singleton access.
    public static let shared = NetworkMonitor()

    /// An optional callback for network changes.
    public typealias NetworkStatusChangeHandler = (
        _ isConnected: Bool,
        _ connectionType: ConnectionType,
        _ radioType: String?
    ) -> Void

    public var statusChangeHandler: NetworkStatusChangeHandler?


    // MARK: - Initialization

    public required init() {}

    deinit {
        stopDetection()
    }


    // MARK: - Instrumentation

    /// Starts monitoring network connectivity changes.
    ///
    /// ## Important
    ///
    /// Call this method after setting up your `statusChangeHandler` if you want to receive
    /// network change callbacks.
    public func startDetection() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else {
                return
            }

            networkChangeEvent.timestamp = Date()
            networkChangeEvent.isConnected = path.status == .satisfied
            networkChangeEvent.connectionType = getConnectionType(path)
            networkChangeEvent.radioType = getCurrentRadioType()

            if isInitialEvent {
                isInitialEvent = false
                previousChangeEvent = networkChangeEvent
            }
            else {
                sendNetworkChangeSpan()
            }
        }
        monitor.start(queue: queue)

        #if canImport(CoreTelephony)
            // Radio Access Technologies detection (connection subtype in Otel)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(radioAccessChanged),
                name: .CTServiceRadioAccessTechnologyDidChange,
                object: nil
            )
        #endif

        // Initial fetch of radio access technologies
        networkChangeEvent.radioType = networkChangeEvent.connectionType == .cellular ? getCurrentRadioType() : nil
    }

    /// Stops monitoring network connectivity changes.
    public func stopDetection() {
        monitor.cancel()
        monitor.pathUpdateHandler = nil

        #if canImport(CoreTelephony)
            NotificationCenter.default.removeObserver(self, name: .CTServiceRadioAccessTechnologyDidChange, object: nil)
        #endif
    }

    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        }

        if path.usesInterfaceType(.cellular) {
            return .cellular
        }

        if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        }

        if path.status == .unsatisfied {
            return .unavailable
        }


        // Check for VPN
        let isVPN = path.availableInterfaces.contains(where: { iface in
            iface.type == .other
                && (iface.name.lowercased().contains("utun") || iface.name.lowercased().contains("ppp") || iface.name.lowercased().contains("ipsec"))
        })

        return isVPN ? .vpn : .other
    }

    private func sendNetworkChangeSpan() {
        if networkChangeEvent.connectionType != .cellular {
            networkChangeEvent.radioType = nil
        }
        if networkChangeEvent.isDebouncedChange(from: previousChangeEvent) {
            destination.send(networkEvent: networkChangeEvent, sharedState: sharedState)

            statusChangeHandler?(
                networkChangeEvent.isConnected,
                networkChangeEvent.connectionType,
                networkChangeEvent.radioType
            )
            previousChangeEvent = networkChangeEvent
        }
    }

    @objc
    private func radioAccessChanged() {
        // Dispatch to our serial queue to ensure thread-safe access to telephonyInfo
        // and add a small delay to allow CoreTelephony to stabilize its internal state
        queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else {
                return
            }

            isInitialEvent = false
            networkChangeEvent.timestamp = Date()
            networkChangeEvent.radioType = getCurrentRadioType()
            sendNetworkChangeSpan()
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private func getCurrentRadioType() -> String? {
        #if canImport(CoreTelephony)
            guard let radioTechnology = telephonyInfo.serviceCurrentRadioAccessTechnology?.values.first else {
                return nil
            }

            if #available(iOS 14.1, *) {
                if radioTechnology == CTRadioAccessTechnologyNRNSA {
                    return "NRNSA (5G Non-Standalone)"
                }
                if radioTechnology == CTRadioAccessTechnologyNR {
                    return "NR (5G Standalone)"
                }
            }

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

            default:
                return nil
            }
        #else
            return nil
        #endif
    }
    // swiftlint:enable cyclomatic_complexity
}
