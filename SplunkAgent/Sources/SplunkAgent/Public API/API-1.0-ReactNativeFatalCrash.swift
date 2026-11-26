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
import OpenTelemetryApi

#if canImport(SplunkCrashReports)
    internal import SplunkCrashReports
#endif

extension SplunkRum {
    /// Persists a fatal React Native JavaScript error as a crash span before process termination.
    ///
    /// This integration method is synchronous and bounded. It returns `true` only after the exact
    /// span has reached durable local storage and PLCrashReporter contains the marker required to
    /// suppress the later native duplicate. It never waits for network delivery.
    ///
    /// - Parameters:
    ///   - message: Original JavaScript error message.
    ///   - stacktrace: Raw Hermes or JavaScriptCore stacktrace.
    ///   - attributes: React Native error and source-map identity attributes.
    /// - Returns: Whether exact local persistence and native suppression arming both succeeded.
    public func recordReactNativeFatalCrashSync(
        message: String,
        stacktrace: String?,
        attributes: MutableAttributes
    ) -> Bool {
        #if canImport(SplunkCrashReports)
            guard
                let eventManager = eventManager as? DefaultEventManager,
                let crashReports = modulesManager?.module(ofType: SplunkCrashReports.CrashReports.self)
            else {
                return false
            }

            let completion = DispatchSemaphore(value: 0)
            let result = ReactNativeFatalCrashResult()

            eventManager.concreteTraceProcessor.emitAndPersistSpan(
                emitting: { [weak self] in
                    guard let self else {
                        return .invalid
                    }

                    let span = makeReactNativeFatalCrashSpan(
                        message: message,
                        stacktrace: stacktrace,
                        attributes: attributes
                    )
                    result.set(spanId: span.context.spanId)
                    span.end()
                    return span.context.spanId
                },
                timeout: ReactNativeFatalCrashConstants.timeout
            ) { succeeded in
                let spanId = result.spanId
                let markerArmed = succeeded
                    && spanId.isValid
                    && crashReports.armReactNativeFatalMarker(spanId: spanId.hexString)
                result.set(succeeded: markerArmed)
                completion.signal()
            }

            guard completion.wait(timeout: .now() + ReactNativeFatalCrashConstants.timeout) == .success else {
                return false
            }

            return result.succeeded
        #else
            return false
        #endif
    }

    private func makeReactNativeFatalCrashSpan(
        message: String,
        stacktrace: String?,
        attributes: MutableAttributes
    ) -> any Span {
        let tracer = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: ReactNativeFatalCrashConstants.instrumentationName
        )
        let span = tracer.spanBuilder(spanName: ReactNativeFatalCrashConstants.spanName).startSpan()

        let forwardedAttributes = attributes.getAll()
        for (key, value) in forwardedAttributes {
            span.setAttribute(key: key, value: value)
        }
        if forwardedAttributes["exception.type"] == nil {
            span.setAttribute(key: "exception.type", value: "Error")
        }
        span.setAttribute(key: "component", value: "crash")
        span.setAttribute(key: "error", value: true)
        span.setAttribute(key: "crash.rumSessionId", value: sharedState.sessionId)
        span.setAttribute(key: "exception.message", value: message)
        if let stacktrace {
            span.setAttribute(key: "exception.stacktrace", value: stacktrace)
        }

        return span
    }
}

private enum ReactNativeFatalCrashConstants {
    static let instrumentationName = "splunk-crash-report"
    static let spanName = "SplunkCrashReport"
    static let timeout: TimeInterval = 2
}

private final class ReactNativeFatalCrashResult {
    private let lock = NSLock()
    private var storedSpanId = SpanId.invalid
    private var storedSucceeded = false

    var spanId: SpanId {
        lock.withLock { storedSpanId }
    }

    var succeeded: Bool {
        lock.withLock { storedSucceeded }
    }

    func set(spanId: SpanId) {
        lock.withLock {
            storedSpanId = spanId
        }
    }

    func set(succeeded: Bool) {
        lock.withLock {
            storedSucceeded = succeeded
        }
    }
}
