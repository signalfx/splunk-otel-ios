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

@available(iOS 12.0, *)
let networkMonitor = NWPathMonitor()

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
                attemptCachedSpansExport()
            }
        }
    }

}
// MARK: - attempt to export from DB
func attemptCachedSpansExport() {
    // way 1 - delete span if size is exceeded.
    CoreDataManager.shared.flushDbIfSizeExceed()
            // OR
    // way 2 -delete spans from db FLUSH FIFO or 4 h time logic.
  // CoreDataManager.shared.flushOutSpanAfterTimePeriod()

    let count = Double(CoreDataManager.shared.getRecordsCount())
    let fetch_count = Int(ceil(count / Double(MAX_FETCH_SPANS)))

    for _ in stride(from: 1, through: fetch_count, by: 1) {
        let dbspans = CoreDataManager.shared.fetchSpanValues()

        if !dbspans.isEmpty {
            // delete exported span only
            CoreDataManager.shared.deleteSpanData(spans: dbspans)
        }
    }

}
