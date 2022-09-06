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
    let networkStatus = CTTelephonyNetworkInfo()
    if #available(iOS 12.0, *) {
        let netInfo = CTTelephonyNetworkInfo()
        let carrier = netInfo.serviceSubscriberCellularProviders?.filter({ $0.value.carrierName != nil }).first?.value
        carrier?.mobileCountryCode
    } else {
        let carrier = networkStatus.subscriberCellularProvider
        if carrier != nil{
           // reportCarrierSpan(carrierName: carrier?.carrierName, isoCountryCode: carrier?.isoCountryCode, mobileCountryCode: carrier?.mobileCountryCode)
        }
    }
}

func reportCarrierSpan(carrierName: String,isoCountryCode: String,mobileCountryCode: String) {
    let tracer = buildTracer()
    let now = Date()
    let typeName = "SplunkRum.reportError(String)"
    let span = tracer.spanBuilder(spanName: typeName).setStartTime(time: now).startSpan()
    span.setAttribute(key: "component", value: "error")
    span.setAttribute(key: "error", value: true)
    span.setAttribute(key: "exception.type", value: "String")
  //  span.setAttribute(key: "exception.message", value: e)
    span.end(time: now)
}



// func getTelephonyInfo()->String?{
//    let networkInfo = CTTelephonyNetworkInfo()
//    let currCarrierType: String?
//    if #available(iOS 12.0, *) {
//        let serviceSubscriberCellularProviders = networkInfo.serviceSubscriberCellularProviders
//        // get curr value:
//        guard let dict = networkInfo.serviceCurrentRadioAccessTechnology else{
//            return nil
//        }
//        // as apple states
//        // https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/3024510-servicecurrentradioaccesstechnol
//        // 1st value is our string:
//        let key = dict.keys.first! // Apple assures is present...
//        // use it on previous dict:
//        let carrierType = dict[key]
//        // to compare:
//        guard let carrierType_OLD = networkInfo.currentRadioAccessTechnology else {
//            return nil
//        }
//        currCarrierType = carrierType
//    } else {
//        // Fall back to pre iOS12
//        guard let carrierType = networkInfo.currentRadioAccessTechnology else {
//            return nil
//        }
//        currCarrierType = carrierType
//    }
//
//}
