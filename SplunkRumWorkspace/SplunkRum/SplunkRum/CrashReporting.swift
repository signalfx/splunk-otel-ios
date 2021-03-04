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
import CrashReporter

// FIXME this whole thing is slapped together; read through the docs some more and
// understand all the choices and possibilities
func initializeCrashReporting() {
    // FIXME why does .mach crash with signal 5 (breakpoint)?
    let config = PLCrashReporterConfig(signalHandlerType: .BSD, symbolicationStrategy: .all)
    let crashReporter_ = PLCrashReporter(configuration: config)
    if crashReporter_ == nil {
        print("Cannot enable PLCrashReporter")
        return
    }
    let crashReporter = crashReporter_!
    let success = crashReporter.enable()
    print("PLCrashReporter enabled: "+success.description)

    if crashReporter.hasPendingCrashReport() {
        print("**** FOUND pending crash report")
        do {
            let data = crashReporter.loadPendingCrashReportData()
            print(data?.count as Any)
            let report = try PLCrashReport(data: data)
            let str = PLCrashReportTextFormatter.stringValue(for: report, with: PLCrashReportTextFormatiOS)
            print(str!)
            // FIXME obviously this needs to turn into a span
        } catch {
            // FIXME error handling
            print("oh no")
        }
        crashReporter.purgePendingCrashReport()
    }
}
