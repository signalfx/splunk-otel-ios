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

/// A representation of a call stack trace, composed of individual string frames.
///
/// This struct encapsulates the stack trace information associated with an error or exception,
/// typically obtained from `Thread.callStackSymbols` or `NSException.callStackSymbols`.
public struct Stacktrace {
    let frames: [String]
}


// MARK: - Stacktrace formatting

public extension Stacktrace {
    /// A single string representation of the stack trace, with each frame separated by a newline character.
    var formatted: String {
        frames.joined(separator: "\n")
    }
}
