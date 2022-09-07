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
import CoreTelephony

func NetworkDetector() {

    let networkInfo = CTTelephonyNetworkInfo()

    if #available(iOS 12.0, *) {

        if let carrier = networkInfo.serviceSubscriberCellularProviders?.filter({ $0.value.carrierName != nil }).first?.value {
            if carrier.mobileCountryCode != nil {
                reportCarrierNameSpan(carrierName: carrier.carrierName!)
            }
        }

    } else {

        let carriers = networkInfo.subscriberCellularProvider
        let mobileCarrierName = carriers?.carrierName
        if mobileCarrierName != nil {
            reportCarrierNameSpan(carrierName: mobileCarrierName!)
        }
    }
}

func reportCarrierNameSpan(carrierName: String) {
    let tracer = buildTracer()
    let now = Date()
    let typeName = "Network"
    let span = tracer.spanBuilder(spanName: typeName).setStartTime(time: now).startSpan()
    span.setAttribute(key: "component", value: "ui")
    span.setAttribute(key: "carrierName", value: carrierName)
    span.end(time: now)
}
