

import Foundation


// MARK: - Stacktrace

public struct Stacktrace {

    public let frames: [String]

    public init(frames: [String]) {
        self.frames = frames
    }
}


// MARK: - Stacktrace formatting

extension Stacktrace {
    public var formatted: String {
        frames.joined(separator: "\n")
    }
}

