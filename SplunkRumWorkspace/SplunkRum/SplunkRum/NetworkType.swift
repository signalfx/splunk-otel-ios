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

@available(iOS 12.0, *)
let networkMonitor = NWPathMonitor()
let carrierInfo    = CTTelephonyNetworkInfo()
var hostConnectionType: String?
func initializeNetworkTypeMonitoring() {
    if #available(iOS 12.0, *) {
        networkMonitor.start(queue: .global(qos: .background))
        // FIXME in case of .cellular, can use CTTelephonyNetworkInfo().ni.currentRadioAccessTechnology to be more descriptive
        networkMonitor.pathUpdateHandler = { (path) in
            if path.status == .satisfied {
                if path.usesInterfaceType(.wifi) {
                    hostConnectionType = "wifi"
                } else if path.usesInterfaceType(.cellular) {
                    hostConnectionType = "cell"
                } else {
                    hostConnectionType = nil
                }
            }
        }
    }

}

func networkDetector() {
    if #available(iOS 12.0, *) {
        if let carrier = carrierInfo.serviceSubscriberCellularProviders {
               carrier.forEach { (_, value) in
                if value.mobileCountryCode != nil {
                    reportCarrierNameSpan(networkCarrierName: value.carrierName!)
                }
            }
        }
    } else {
        let networkCarrier = carrierInfo.subscriberCellularProvider
        let networkCarrierName = networkCarrier?.carrierName
        if networkCarrierName != nil {
            reportCarrierNameSpan(networkCarrierName: networkCarrierName!)
        }
    }
}

func reportCarrierNameSpan(networkCarrierName: String) {
    let tracer = buildTracer()
    let now = Date()
    let typeName = "Network"
    let span = tracer.spanBuilder(spanName: typeName).setStartTime(time: now).startSpan()
    span.setAttribute(key: "component", value: "ui")
    span.setAttribute(key: "carrierName", value: networkCarrierName)
    span.end(time: now)
}
