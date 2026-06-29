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

typealias StackFrameImageNameResolver = (_ instructionPointer: UInt64, _ parsedImageName: String?) -> String?


// MARK: - Stacktrace formatting

extension Stacktrace {
    public var formatted: String {
        frames.joined(separator: "\n")
    }

    var threadList: String? {
        threadList()
    }

    func threadList(resolvingImageNamesWith imageNameResolver: StackFrameImageNameResolver? = nil) -> String? {
        let stackFrames = frames.map { frame in
            var attributes = ParsedStackFrame(from: frame).attributes

            if
                let instructionPointer = attributes[.instructionPointer] as? UInt64,
                let resolvedImageName = imageNameResolver?(instructionPointer, attributes[.imageName] as? String),
                !resolvedImageName.isEmpty
            {
                attributes[.imageName] = resolvedImageName
            }

            return attributes
        }

        let thread: [ErrorDiagnosticKeys: Any] = [
            .stackFrames: stackFrames
        ]

        return ErrorDiagnosticJSON.convertToJSONString([thread])
    }

    var referencedImageNames: Set<String> {
        var imageNames: Set<String> = []

        for frame in frames {
            let parsedFrame = ParsedStackFrame(from: frame)
            guard let imageName = parsedFrame.attributes[.imageName] as? String else {
                continue
            }

            imageNames.formUnion(normalizedImageNames(imageName))
        }

        return imageNames
    }
}


// MARK: - Image name normalization

func normalizedImageNames(_ imageName: String) -> Set<String> {
    let names = [
        imageName,
        (imageName as NSString).lastPathComponent
    ]

    return Set(names.filter { !$0.isEmpty })
}


// MARK: - Stack frame parsing

private struct ParsedStackFrame {
    private static let expression = try? NSRegularExpression(
        pattern: #"^\s*(\d+)\s+(.+?)\s+(0x[0-9a-fA-F]+)\s+(.*?)(?:\s+\+\s+(\d+))?\s*$"#
    )

    let attributes: [ErrorDiagnosticKeys: Any]

    init(from frame: String) {
        guard
            let match = Self.expression?.firstMatch(
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

        let imageName = substring(in: frame, for: match.range(at: 2))
        if !imageName.isEmpty {
            output[.imageName] = imageName
        }

        let instructionPointer = substring(in: frame, for: match.range(at: 3))
        if let instructionPointerValue = UInt64(instructionPointer.dropFirst(2), radix: 16) {
            output[.instructionPointer] = instructionPointerValue
        }

        let symbolName = substring(in: frame, for: match.range(at: 4))
        if !symbolName.isEmpty {
            output[.symbolName] = symbolName
        }

        let offset = substring(in: frame, for: match.range(at: 5))
        if let offsetValue = UInt64(offset) {
            output[.offset] = offsetValue
        }

        attributes = output
    }
}


// MARK: - String parsing

private func substring(in string: String, for range: NSRange) -> String {
    guard
        range.location != NSNotFound,
        let range = Range(range, in: string)
    else {
        return ""
    }

    return String(string[range]).trimmingCharacters(in: .whitespaces)
}
