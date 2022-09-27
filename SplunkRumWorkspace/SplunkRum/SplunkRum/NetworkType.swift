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
// swiftlint:disable cyclomatic_complexity
import Foundation
import SystemConfiguration
import Network
import CoreTelephony

@available(iOS 12.0, *)
let networkMonitor = NWPathMonitor()
let networkInfo    = CTTelephonyNetworkInfo()
var hostConnectionType: String?
var hostConnectionSubtype: String?
var hostConnectionName: String?
func initializeNetworkTypeMonitoring() {
    if #available(iOS 12.0, *) {
        networkMonitor.start(queue: .global(qos: .background))
        // FIXME in case of .cellular, can use CTTelephonyNetworkInfo().ni.currentRadioAccessTechnology to be more descriptive
        networkMonitor.pathUpdateHandler = { (path) in
            if path.status == .satisfied {
                if path.usesInterfaceType(.wifi) {
                    hostConnectionType = "wifi"
                    hostConnectionSubtype = getNetworkInfo()
                } else if path.usesInterfaceType(.cellular) {
                    hostConnectionType = "cell"
                    hostConnectionSubtype = getNetworkInfo()
                    networkDetector()
                } else {
                    hostConnectionType = nil
                    hostConnectionSubtype = nil
                }
            }
        }
    }
}

func networkDetector() {
    if #available(iOS 12.0, *) {
        if let carrier = networkInfo.serviceSubscriberCellularProviders {
               carrier.forEach { (_, value) in
                if value.mobileCountryCode != nil {
                    hostConnectionName = value.carrierName
                }
            }
        }
    } else {
        let networkCarrier = networkInfo.subscriberCellularProvider
        let networkCarrierName = networkCarrier?.carrierName
        if networkCarrierName != nil {
            hostConnectionName = networkCarrierName
        }
    }
}

 func getNetworkInfo() -> String? {

     if #available(iOS 12.0, *) {
         guard let dict = networkInfo.serviceCurrentRadioAccessTechnology else {
             return nil
         }
         if dict.count != 0 {
             let key = dict.keys.first!
             let networkCarrierType = dict[key]
             hostConnectionSubtype = networkCarrierType
         } else {
             return nil
         }

     } else {
         guard let carrierType = networkInfo.currentRadioAccessTechnology else {
             return nil
         }
         hostConnectionSubtype = carrierType
     }

    switch hostConnectionSubtype {
    case CTRadioAccessTechnologyGPRS:
        return "2G" + " (GPRS)"
    case CTRadioAccessTechnologyEdge:
        return "2G" + " (Edge)"
    case CTRadioAccessTechnologyCDMA1x:
        return "2G" + " (CDMA1x)"
    case CTRadioAccessTechnologyWCDMA:
        return "3G" + " (WCDMA)"
    case CTRadioAccessTechnologyHSDPA:
        return "3G" + " (HSDPA)"
    case CTRadioAccessTechnologyHSUPA:
        return "3G" + " (HSUPA)"
    case CTRadioAccessTechnologyCDMAEVDORev0:
        return "3G" + " (CDMAEVDORev0)"
    case CTRadioAccessTechnologyCDMAEVDORevA:
        return "3G" + " (CDMAEVDORevA)"
    case CTRadioAccessTechnologyCDMAEVDORevB:
        return "3G" + " (CDMAEVDORevB)"
    case CTRadioAccessTechnologyeHRPD:
        return "3G" + " (eHRPD)"
    case CTRadioAccessTechnologyLTE:
        return "4G" + " (LTE)"
    default:
        break
    }
    return "New_Network_Type"
}
