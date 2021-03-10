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
import UIKit
import OpenTelemetryApi

private func processStartTime() throws -> Date {
    let name = "kern.proc.pid"
    var len: size_t = 4
    var mib = [Int32](repeating: 0, count: 4)
    var kp: kinfo_proc = kinfo_proc()
    try mib.withUnsafeMutableBufferPointer { (mibBP: inout UnsafeMutableBufferPointer<Int32>) throws in
        try name.withCString { (nbp: UnsafePointer<Int8>) throws in
            guard sysctlnametomib(nbp, mibBP.baseAddress, &len) == 0 else {
                throw POSIXError(.EAGAIN)
            }
        }
        mibBP[3] = getpid()
        len =  MemoryLayout<kinfo_proc>.size
        guard sysctl(mibBP.baseAddress, 4, &kp, &len, nil, 0) == 0 else {
            throw POSIXError(.EAGAIN)
        }
    }
    // Type casts to finally produce the answer
    let startTime = kp.kp_proc.p_un.__p_starttime
    let ti: TimeInterval = Double(startTime.tv_sec) + (Double(startTime.tv_usec) / 1e6)
    return Date(timeIntervalSince1970: ti)
}

// FIXME note that this returns things like "iPhone13,3" which means "iPhone 12 Pro" but the mapping isn't
// -> one possible solution is https://github.com/devicekit/DeviceKit
func getDeviceModel() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    let model = mirror.children.reduce("") { id, element in
        guard let value = element.value as? Int8, value != 0 else { return id }
        return id + String(UnicodeScalar(UInt8(value)))
    }
    if model.isEmpty {
        return "unknown"
    }
    return model
}

func sendAppStartSpan() {
    let tracer = buildTracer()
    // FIXME timestamps!
    // FIXME names for things
    let appStart = tracer.spanBuilder(spanName: "AppStart").startSpan()
    appStart.setAttribute(key: "device.model", value: getDeviceModel())
    appStart.setAttribute(key: "os.version", value: UIDevice.current.systemVersion)
    do {
        let start = try processStartTime()
        appStart.addEvent(name: "process.start", timestamp: start)
    } catch {
        // swallow
    }
    appStart.end()
}
