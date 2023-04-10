//
/*
Copyright 2021 Splunk Inc.

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
import SystemConfiguration
import Network
import CoreTelephony

struct NetworkInfo {
    var hostConnectionType: String?
    var hostConnectionSubType: String?
    var carrierCountryCode: String?
    var carrierNetworkCode: String?
    var carrierIsoCountryCode: String?
    var carrierName: String?
}

#if os(iOS) && !targetEnvironment(macCatalyst)
fileprivate var currentNetInfo: NetworkInfo = NetworkInfo()
fileprivate var netInfoLock = pthread_rwlock_t()
@available(iOS 12.0, *)
fileprivate let networkMonitor = NWPathMonitor()
fileprivate let telephonyNetworkInfo = CTTelephonyNetworkInfo()

private func setConnectionType(_ type: String?) {
    pthread_rwlock_wrlock(&netInfoLock)
    defer {
        pthread_rwlock_unlock(&netInfoLock)
    }
    currentNetInfo.hostConnectionType = type
}

private func setCarrierInfo(name: String?, technology: String?, countryCode: String?, networkCode: String?, isoCountryCode: String?) {
    pthread_rwlock_wrlock(&netInfoLock)
    defer {
        pthread_rwlock_unlock(&netInfoLock)
    }
    if currentNetInfo.hostConnectionType != "cell" {
        currentNetInfo.carrierName = nil
        currentNetInfo.hostConnectionSubType = nil
        currentNetInfo.carrierCountryCode = nil
        currentNetInfo.carrierNetworkCode = nil
        currentNetInfo.carrierIsoCountryCode = nil

    } else {
        currentNetInfo.carrierName = name
        currentNetInfo.hostConnectionSubType = technology
        currentNetInfo.carrierCountryCode = countryCode
        currentNetInfo.carrierNetworkCode = networkCode
        currentNetInfo.carrierIsoCountryCode = isoCountryCode
    }

}

@available(iOS 12.0, *)
private func setCarrierInfo(_ netInfo: CTTelephonyNetworkInfo, identifier: String?) {
    if identifier == nil {
        return
    }

    let carrierInfo = netInfo.serviceSubscriberCellularProviders?[identifier!]
    let tech = netInfo.serviceCurrentRadioAccessTechnology?[identifier!]
    setCarrierInfo(name: carrierInfo?.carrierName,
                   technology: shortTech(tech),
                   countryCode: carrierInfo?.mobileCountryCode,
                   networkCode: carrierInfo?.mobileNetworkCode,
                   isoCountryCode: carrierInfo?.isoCountryCode)
}

private func shortTech(_ tech: String?) -> String? {
    switch tech {
    case CTRadioAccessTechnologyGPRS:
        return "gprs"
    case CTRadioAccessTechnologyCDMA1x:
        return "cdma"
    case CTRadioAccessTechnologyEdge:
        return "edge"
    case CTRadioAccessTechnologyWCDMA:
        return "wcdma"
    case CTRadioAccessTechnologyHSDPA:
        return "hsdpa"
    case CTRadioAccessTechnologyHSUPA:
        return "hsupa"
    case CTRadioAccessTechnologyCDMAEVDORev0:
        return "evdo_0"
    case CTRadioAccessTechnologyCDMAEVDORevA:
        return "evdo_a"
    case CTRadioAccessTechnologyCDMAEVDORevB:
        return "evdo_b"
    case CTRadioAccessTechnologyeHRPD:
        return "ehrpd"
    case CTRadioAccessTechnologyLTE:
        return "lte"
    default:
        break
    }
    return nil
}

func getNetworkInfo() -> NetworkInfo {
    pthread_rwlock_rdlock(&netInfoLock)
    var info = currentNetInfo
    pthread_rwlock_unlock(&netInfoLock)

    // swiftlint:disable unavailable_condition
    if #available(iOS 12, *) {} else {
        let netInfo = CTTelephonyNetworkInfo()
        let carrier = netInfo.subscriberCellularProvider
        if carrier != nil {
            info.carrierName = carrier!.carrierName
            info.carrierIsoCountryCode = carrier!.isoCountryCode
            info.carrierNetworkCode = carrier!.mobileNetworkCode
            info.carrierCountryCode = carrier!.mobileCountryCode
        }

        let technology = netInfo.currentRadioAccessTechnology
        if technology != nil {
            info.hostConnectionSubType = shortTech(technology)
        }
    }
    // swiftlint:enable unavailable_condition

    return info
}

func initializeNetworkTypeMonitoring() {
    pthread_rwlock_init(&netInfoLock, nil)
    if #available(iOS 12.0, *) {
        networkMonitor.start(queue: .global(qos: .background))
        networkMonitor.pathUpdateHandler = { (path) in
            if path.status == .satisfied {
                if path.usesInterfaceType(.wifi) {
                    setConnectionType("wifi")
                } else if path.usesInterfaceType(.cellular) {
                    setConnectionType("cell")
                } else {
                    setConnectionType(nil)
                }
            } else {
                setConnectionType(nil)
            }
        setCarrierInfo(telephonyNetworkInfo, identifier: telephonyNetworkInfo.serviceCurrentRadioAccessTechnology?.keys.first)
    }
        telephonyNetworkInfo.serviceSubscriberCellularProvidersDidUpdateNotifier = { identifier in
            setCarrierInfo(telephonyNetworkInfo, identifier: identifier)
        }
    }
}
#else
func initializeNetworkTypeMonitoring() {}
func getNetworkInfo() -> NetworkInfo {
    return NetworkInfo()
}
#endif
