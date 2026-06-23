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

// MARK: - Stacktrace

public struct Stacktrace {
    let frames: [String]
}


// MARK: - Stacktrace formatting

extension Stacktrace {
    public var formatted: String {
        frames.joined(separator: "\n")
    }

    var threadList: String? {
        let stackFrames = frames.map { frame in
            ParsedStackFrame(from: frame).attributes
        }

        let thread: [ErrorDiagnosticKeys: Any] = [
            .threadNumber: 0,
            .isCrashedThread: true,
            .stackFrames: stackFrames
        ]

        return ErrorDiagnosticJSON.convertToJSONString([thread])
    }
}


// MARK: - Stack frame parsing

private struct ParsedStackFrame {
    let attributes: [ErrorDiagnosticKeys: Any]

    init(from frame: String) {
        let pattern = #"^\s*(\d+)\s+(.+?)\s+(0x[0-9a-fA-F]+)\s+(.*?)(?:\s+\+\s+(\d+))?\s*$"#

        guard
            let expression = try? NSRegularExpression(pattern: pattern),
            let match = expression.firstMatch(
                in: frame,
                range: NSRange(frame.startIndex..., in: frame)
            )
        else {
            attributes = [
                .symbolName: frame
            ]
            return
        }

        var output: [ErrorDiagnosticKeys: Any] = [:]

        let imageName = frame.substring(for: match.range(at: 2))
        if !imageName.isEmpty {
            output[.imageName] = imageName
        }

        let instructionPointer = frame.substring(for: match.range(at: 3))
        if let instructionPointerValue = UInt64(instructionPointer.dropFirst(2), radix: 16) {
            output[.instructionPointer] = instructionPointerValue
        }

        let symbolName = frame.substring(for: match.range(at: 4))
        if !symbolName.isEmpty {
            output[.symbolName] = symbolName
        }

        let offset = frame.substring(for: match.range(at: 5))
        if let offsetValue = UInt64(offset) {
            output[.offset] = offsetValue
        }

        attributes = output
    }
}


// MARK: - String parsing

extension String {
    fileprivate func substring(for range: NSRange) -> String {
        guard
            range.location != NSNotFound,
            let range = Range(range, in: self)
        else {
            return ""
        }

        return String(self[range]).trimmingCharacters(in: .whitespaces)
    }
}
