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
import SplunkSharedProtocols


// MARK: - TrackedError

public final class TrackedError {
    
    // MARK: - Properties
    
    private var config: CustomTrackingConfiguration
    private var dataConsumer: ((TrackedErrorEventMetadata, TrackedErrorEventData) -> Void)?
    
    // MARK: - Initialization
    
    public required init() {
        self.config = CustomTrackingConfiguration(enabled: true)
    }
}


// MARK: - Public API

extension TrackedError {
    /// Track any error that conforms to TrackableIssue
    /// - Parameters:
    ///   - error: The error to be tracked
    ///   - serviceName: Optional name of the service where the error occurred
    public func trackError<T: TrackableIssue>(
        _ error: T,
        serviceName: String? = nil,
    ) {
        guard config.enabled else { return }
        
        let metadata = TrackedErrorEventMetadata(
            timestamp: Date(),
            errorType: error.typeName
        )
        
        let eventData = TrackedErrorEventData(
            issue: error,
            domain: getDomain(for: error),
            code: getErrorCode(for: error),
            serviceName: serviceName,
        )
        
        dataConsumer?(metadata, eventData)
    }
}


// MARK: - Private Helpers

private extension TrackedError {
    func getDomain(for error: any TrackableIssue) -> String {
        switch error {
        case let nsError as NSError:
            return nsError.domain
        case let exception as NSException:
            return exception.name.rawValue
        default:
            return String(describing: type(of: error))
        }
    }
    
    func getErrorCode(for error: any TrackableIssue) -> Int? {
        (error as? NSError)?.code
    }
}


//// cruft from TrackableIssue:
///
///
///
// MARK: - Stacktrace

public struct Stacktrace {
    /// The individual frames of the stack trace
    public let frames: [String]

    public init(frames: [String]) {
        self.frames = frames
    }
}


// MARK: - Stacktrace Formatting

extension Stacktrace {
    /// Returns a formatted string representation of the stack trace
    public var formatted: String {
        frames.joined(separator: "\n")
    }
}


// MARK: - Error Conformance

extension Error where Self: TrackableIssue {
    public var typeName: String { String(describing: type(of: self)) }
    public var message: String { localizedDescription }
    public var stacktrace: Stacktrace? {
        Stacktrace(frames: Thread.callStackSymbols)
    }
}


// MARK: - NSError Conformance

extension NSError: TrackableIssue {
    public var typeName: String { domain }
    public var message: String { localizedDescription }
    public var stacktrace: Stacktrace? {
        Stacktrace(frames: Thread.callStackSymbols)
    }
}


// MARK: - NSException Conformance

extension NSException: TrackableIssue {
    public var typeName: String { name.rawValue }
    public var message: String { reason ?? "No reason provided" }
    public var stacktrace: Stacktrace? {
        Stacktrace(frames: callStackSymbols)
    }
}

