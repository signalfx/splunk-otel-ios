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

    /// Indicates the stack is a caller-supplied verbatim string (for example a
    /// bridged JavaScript/Dart stack) rather than native `Thread.callStackSymbols`
    /// frames.
    ///
    /// Verbatim stacks are emitted only as `exception.stacktrace` and are never
    /// parsed into native `exception.threads` diagnostics or scanned for binary
    /// images, since those parsers only understand native frame lines.
    let isVerbatim: Bool

    init(frames: [String]) {
        self.frames = frames
        isVerbatim = false
    }
}

typealias StackFrameImageNameResolver = (_ instructionPointer: UInt64, _ parsedImageName: String?) -> String?

struct StackFrame {
    #if arch(x86_64) || arch(i386)
        static let returnAddressAdjustment: UInt64 = 1
    #elseif arch(arm64) || arch(arm64_32) || arch(arm)
        static let returnAddressAdjustment: UInt64 = 4
    #else
        static let returnAddressAdjustment: UInt64 = 0
    #endif

    let index: Int
    let attributes: [ErrorDiagnosticKeys: Any]

    var instructionPointer: UInt64? {
        attributes[.instructionPointer] as? UInt64
    }

    var parsedImageName: String? {
        attributes[.imageName] as? String
    }

    var symbolicationInstructionPointer: UInt64? {
        guard let instructionPointer else {
            return nil
        }

        return appliesReturnAddressAdjustment ? instructionPointer - Self.returnAddressAdjustment : instructionPointer
    }

    var symbolicationAttributes: [ErrorDiagnosticKeys: Any] {
        var output = attributes

        if let symbolicationInstructionPointer {
            output[.instructionPointer] = symbolicationInstructionPointer
        }

        if dropsStaleSymbolInfo {
            output[.symbolName] = nil
            output[.offset] = nil
        }
        else if let adjustedOffset {
            output[.offset] = adjustedOffset
        }

        return output
    }

    init(index: Int, frame: String) {
        self.index = index
        attributes = ParsedStackFrame(from: frame).attributes
    }

    private var appliesReturnAddressAdjustment: Bool {
        guard index > 0, let instructionPointer else {
            return false
        }

        return Self.returnAddressAdjustment > 0 && instructionPointer >= Self.returnAddressAdjustment
    }

    private var dropsStaleSymbolInfo: Bool {
        guard
            appliesReturnAddressAdjustment,
            let offset = attributes[.offset] as? UInt64
        else {
            return false
        }

        // The parsed symbol and offset describe the return address. If adjusting
        // the pointer would move before that symbol, avoid emitting a stale pair.
        return offset < Self.returnAddressAdjustment
    }

    private var adjustedOffset: UInt64? {
        guard
            appliesReturnAddressAdjustment,
            let offset = attributes[.offset] as? UInt64,
            offset >= Self.returnAddressAdjustment
        else {
            return nil
        }

        return offset - Self.returnAddressAdjustment
    }
}

struct StacktraceImageReferences {
    let exactImagePaths: Set<String>
    let fallbackImageNames: Set<String>

    var isEmpty: Bool {
        exactImagePaths.isEmpty && fallbackImageNames.isEmpty
    }
}


// MARK: - Stacktrace initialization

extension Stacktrace {

    /// Creates a stacktrace from a single, already-formatted verbatim string.
    ///
    /// Use this for explicitly-supplied stacks (for example cross-platform
    /// JavaScript/Dart stacks bridged from React Native or Flutter) that must be
    /// emitted exactly as provided, without re-deriving or reformatting frames.
    /// ``formatted`` then returns the original string unchanged, preserving it as
    /// the raw symbolication input.
    ///
    /// - Parameter raw: The verbatim stacktrace string to emit unmodified.
    init(raw: String) {
        frames = [raw]
        isVerbatim = true
    }
}


// MARK: - Stacktrace formatting

extension Stacktrace {
    public var formatted: String {
        frames.joined(separator: "\n")
    }

    var parsedFrames: [StackFrame] {
        // A verbatim stack is not native `Thread.callStackSymbols` output, so
        // parsing it would fabricate a single bogus frame. Skip it entirely.
        guard !isVerbatim else {
            return []
        }

        var output: [StackFrame] = []

        for (index, frame) in frames.enumerated() {
            output.append(StackFrame(index: index, frame: frame))
        }

        return output
    }

    var symbolicationInstructionPointers: [UInt64] {
        parsedFrames.compactMap(\.symbolicationInstructionPointer)
    }

    var threadList: String? {
        threadList()
    }

    func threadList(resolvingImageNamesWith imageNameResolver: StackFrameImageNameResolver? = nil) -> String? {
        // Verbatim stacks (e.g. bridged JS/Dart) carry no native thread info.
        // Returning nil here keeps the explicit-stack path truly verbatim and
        // avoids the parsing/JSON work of building a synthetic thread list.
        guard !isVerbatim else {
            return nil
        }

        return threadList(from: parsedFrames, resolvingImageNamesWith: imageNameResolver)
    }

    func threadList(
        from parsedFrames: [StackFrame],
        resolvingImageNamesWith imageNameResolver: StackFrameImageNameResolver? = nil
    ) -> String? {
        let stackFrames = parsedFrames.map { frame in
            var attributes = frame.symbolicationAttributes

            if let instructionPointer = frame.symbolicationInstructionPointer,
                let resolvedImageName = imageNameResolver?(instructionPointer, frame.parsedImageName),
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
        referencedImageNames()
    }

    func referencedImageNames(resolvingImageNamesWith imageNameResolver: StackFrameImageNameResolver? = nil) -> Set<String> {
        let references = imageReferences(resolvingImageNamesWith: imageNameResolver)

        return references.exactImagePaths.union(references.fallbackImageNames)
    }

    func imageReferences(resolvingImageNamesWith imageNameResolver: StackFrameImageNameResolver? = nil) -> StacktraceImageReferences {
        var exactImagePaths: Set<String> = []
        var fallbackImageNames: Set<String> = []

        for frame in parsedFrames {
            let parsedImageName = frame.parsedImageName
            let resolvedImageName = frame.symbolicationInstructionPointer.flatMap { instructionPointer in
                imageNameResolver?(instructionPointer, frame.parsedImageName)
            }

            if let resolvedImageName, !resolvedImageName.isEmpty {
                exactImagePaths.insert(resolvedImageName)
            }
            else if let parsedImageName, !parsedImageName.isEmpty {
                fallbackImageNames.formUnion(normalizedImageNames(parsedImageName))
            }
        }

        return StacktraceImageReferences(
            exactImagePaths: exactImagePaths,
            fallbackImageNames: fallbackImageNames
        )
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
            let match = Self.expression?
                .firstMatch(
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
