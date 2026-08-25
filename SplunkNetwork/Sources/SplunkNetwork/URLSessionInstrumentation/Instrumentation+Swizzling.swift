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

import CiscoLogger
import Foundation
import OpenTelemetryApi

private var associatedKeySpanResume: UInt8 = 0

extension URLSessionTask {
    @objc
    open func splunkSwizzledSetState(state: URLSessionTask.State) {
        defer {
            splunkSwizzledSetState(state: state)
        }
        if !isSupportedTask(task: self) {
            return
        }
        // Only a completed task has stable response, metrics, and error information. Suspended and
        // canceling are intermediate states and must not finalize the span.
        guard shouldFinalizeNetworkSpan(for: state) else {
            return
        }

        if currentRequest?.url == nil {
            return
        }

        guard let finalizationCoordinator = getSpanFinalizationCoordinator(for: self) else {
            return
        }

        finalizationCoordinator.finalize(task: self)
    }

    @objc
    open func splunkSwizzledResume() {
        defer {
            splunkSwizzledResume()
        }
        if !isSupportedTask(task: self) {
            return
        }
        if state == Self.State.completed || state == Self.State.canceling {
            return
        }

        // For tasks instrumented at creation time, record the actual network start.
        // The span is started at creation (required for traceparent header injection),
        // but actual network activity only begins at resume. The event allows downstream
        // systems to compute accurate network duration.
        if wasInstrumentedAtCreation(self) {
            getCreationSpan(for: self)?.addEvent(name: "http.request.started")
            return
        }

        if wasSkippedForInstrumentation(self) {
            return
        }

        // Check if we already have a span from a previous resume call
        let existingSpan: Span? = objc_getAssociatedObject(self, &associatedKeySpanResume) as? Span
        if existingSpan != nil {
            return
        }

        // Fallback: create span at resume time (no header injection possible).
        // Covers tasks created before agent initialization or via un-swizzled APIs.
        guard let span = startHttpSpan(request: currentRequest) else {
            return
        }

        let finalizationCoordinator = NetworkSpanFinalizationCoordinator(span: span)
        objc_setAssociatedObject(self, &associatedKeySpanResume, span, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        setSpanFinalizationCoordinator(finalizationCoordinator, for: self)
    }
}

/// Returns whether a URL session task state has stable terminal response information.
func shouldFinalizeNetworkSpan(for state: URLSessionTask.State) -> Bool {
    state == .completed
}

/// Swizzles two methods on a given class.
///
/// - Parameters:
///   - oneClass: The class containing the methods to swizzle.
///   - original: The original method selector.
///   - swizzled: The swizzled method selector.
func swizzle(oneClass: AnyClass, original: Selector, swizzled: Selector) {
    let originalMethod = class_getInstanceMethod(oneClass, original)
    let swizzledMethod = class_getInstanceMethod(oneClass, swizzled)
    if let originalMethod, let swizzledMethod {
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "could not swizzle \(NSStringFromSelector(original))"
        }
    }
}

/// Discovers URLSession classes that need to be swizzled.
///
/// - Returns: Array of classes that override the setState: method.
func swizzledUrlSessionClasses() -> [AnyClass] {
    let configuration = URLSessionConfiguration.ephemeral
    let session = URLSession(configuration: configuration)
    guard let url = URL(string: "https://splunkrum") else {
        return []
    }

    let localDataTask = session.dataTask(with: url)

    defer {
        localDataTask.cancel()
        session.finishTasksAndInvalidate()
    }

    let setStateSelector = NSSelectorFromString("setState:")
    var classes: [AnyClass] = []
    guard var currentClass: AnyClass = object_getClass(localDataTask) else {
        return classes
    }

    var method = class_getInstanceMethod(currentClass, setStateSelector)
    while let currentMethod = method {
        let classResumeImp = method_getImplementation(currentMethod)
        let superClass: AnyClass? = currentClass.superclass()
        let superClassMethod = class_getInstanceMethod(superClass, setStateSelector)
        let superClassResumeImp = superClassMethod.map { method_getImplementation($0) }

        if classResumeImp != superClassResumeImp {
            classes.append(currentClass)
        }

        guard let nextClass = superClass else {
            return classes
        }

        currentClass = nextClass
        method = superClassMethod
    }
    return classes
}

/// Performs method swizzling on URLSession classes.
func swizzleUrlSession() {
    let classes = swizzledUrlSessionClasses()

    let setStateSelector = NSSelectorFromString("setState:")
    let resumeSelector = NSSelectorFromString("resume")

    for classToSwizzle in classes {
        swizzle(oneClass: classToSwizzle, original: setStateSelector, swizzled: #selector(URLSessionTask.splunkSwizzledSetState(state:)))
        swizzle(oneClass: classToSwizzle, original: resumeSelector, swizzled: #selector(URLSessionTask.splunkSwizzledResume))
    }
}
