//
/*
Copyright 2026 Splunk Inc.

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
import MachO
import SplunkCrashReporter
import XCTest

final class CrashReporterEncodingTests: XCTestCase {

    func testProcessPathExcludesTrailingNullByte() throws {
        let configuration = SPLKPLCrashReporterConfig.defaultConfiguration()
        let reporter = try XCTUnwrap(SPLKPLCrashReporter(configuration: configuration))
        let report = try XCTUnwrap(reporter.generateLiveReport())

        let protobuf = report.dropFirst(MemoryLayout<PLCrashReportFileHeader>.size)
        let processInfo = try XCTUnwrap(lengthDelimitedField(7, in: Data(protobuf)))
        let processPath = try XCTUnwrap(lengthDelimitedField(3, in: processInfo))

        XCTAssertEqual(String(data: processPath, encoding: .utf8), executablePath())
        XCTAssertNotEqual(processPath.last, 0)
    }

    private func executablePath() -> String {
        var length: UInt32 = 0
        _NSGetExecutablePath(nil, &length)

        var path = [CChar](repeating: 0, count: Int(length))
        _NSGetExecutablePath(&path, &length)

        return path.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return ""
            }

            return String(cString: baseAddress)
        }
    }

    private func lengthDelimitedField(_ fieldNumber: Int, in data: Data) throws -> Data? {
        let bytes = Array(data)
        var index = 0

        while index < bytes.count {
            let key = try readVarint(from: bytes, index: &index)
            let wireType = Int(key & 0x07)

            if wireType == 2 {
                let length = try readVarint(from: bytes, index: &index)
                let endIndex = index + Int(length)
                guard endIndex <= bytes.count else {
                    throw ProtobufError.truncated
                }

                if Int(key >> 3) == fieldNumber {
                    return Data(bytes[index ..< endIndex])
                }

                index = endIndex
            } else {
                try skipField(wireType: wireType, bytes: bytes, index: &index)
            }
        }

        return nil
    }

    private func readVarint(from bytes: [UInt8], index: inout Int) throws -> UInt64 {
        var result: UInt64 = 0

        for shift in stride(from: 0, through: 63, by: 7) {
            guard index < bytes.count else {
                throw ProtobufError.truncated
            }

            let byte = bytes[index]
            index += 1
            result |= UInt64(byte & 0x7f) << UInt64(shift)

            if byte & 0x80 == 0 {
                return result
            }
        }

        throw ProtobufError.invalidVarint
    }

    private func skipField(wireType: Int, bytes: [UInt8], index: inout Int) throws {
        switch wireType {
        case 0:
            _ = try readVarint(from: bytes, index: &index)

        case 1:
            index += 8

        case 5:
            index += 4

        default:
            throw ProtobufError.unsupportedWireType
        }

        guard index <= bytes.count else {
            throw ProtobufError.truncated
        }
    }
}

private enum ProtobufError: Error {
    case invalidVarint
    case truncated
    case unsupportedWireType
}
