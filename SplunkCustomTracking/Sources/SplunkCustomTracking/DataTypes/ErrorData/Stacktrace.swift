

import Foundation


// MARK: - Stacktrace

public struct Stacktrace {

    // The individual frames of the stacktrace
    public let frames: [String]

    public init(frames: [String]) {
        self.frames = frames
    }
}


// MARK: - Stacktrace Formatting

extension Stacktrace {
    // Returns a formatted string representation of the stacktrace
    public var formatted: String {
        frames.joined(separator: "\n")
    }
}

