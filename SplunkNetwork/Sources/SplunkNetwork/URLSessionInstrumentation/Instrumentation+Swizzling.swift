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
import ObjectiveC.runtime
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

        // For tasks instrumented at creation time, start the telemetry watchdog at the first
        // resume. The span is created earlier (required for traceparent header injection), but
        // actual network activity only begins at resume.
        if wasInstrumentedAtCreation(self) {
            getSpanFinalizationCoordinator(for: self)?.start(task: self)
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
        finalizationCoordinator.start(task: self)
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
        let originalImplementation = method_getImplementation(originalMethod)
        let originalTypeEncoding = method_getTypeEncoding(originalMethod)
        let swizzledImplementation = method_getImplementation(swizzledMethod)
        let swizzledTypeEncoding = method_getTypeEncoding(swizzledMethod)

        // `class_getInstanceMethod` can return a method inherited from a superclass. Add
        // class-local copies before exchanging implementations so swizzling one task subclass
        // cannot replace the saved implementation used by a sibling subclass.
        class_addMethod(oneClass, original, originalImplementation, originalTypeEncoding)
        class_addMethod(oneClass, swizzled, swizzledImplementation, swizzledTypeEncoding)

        if let classOriginalMethod = class_getInstanceMethod(oneClass, original),
            let classSwizzledMethod = class_getInstanceMethod(oneClass, swizzled)
        {
            method_exchangeImplementations(classOriginalMethod, classSwizzledMethod)
        }
        else {
            NetworkInstrumentationManager.shared.logger.log(level: .fault) {
                "could not install class-local swizzle for \(NSStringFromSelector(original))"
            }
        }
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
    var seenClasses = Set<ObjectIdentifier>()

    // Normally the probe task gives us the concrete Foundation task class. Some agents return
    // proxy objects here, though, and the proxy's class hierarchy may not expose setState:. In
    // that case, find already-loaded URLSessionTask subclasses directly in the Objective-C
    // runtime so we can still hook the underlying Foundation implementations.
    if let taskClass = object_getClass(localDataTask) {
        var currentClass: AnyClass? = taskClass
        while let candidate = currentClass {
            appendIfOverridesSetState(candidate, selector: setStateSelector, to: &classes, seen: &seenClasses)
            currentClass = class_getSuperclass(candidate)
        }
    }

    // Keep the normal installation path limited to the probe task's class hierarchy. Scan the
    // runtime only when a proxy prevents the probe from exposing any hookable task classes.
    guard classes.isEmpty else {
        return classes
    }

    var classCount = Int(objc_getClassList(nil, 0))
    guard classCount > 0 else {
        return classes
    }

    while true {
        var runtimeClasses = [AnyClass?](repeating: nil, count: classCount)
        let copiedCount = runtimeClasses.withUnsafeMutableBufferPointer { buffer -> Int in
            guard let baseAddress = buffer.baseAddress else {
                return 0
            }
            return Int(objc_getClassList(AutoreleasingUnsafeMutablePointer(baseAddress), Int32(classCount)))
        }

        // The runtime can load classes while the list is being copied. Retry with a larger
        // buffer rather than silently omitting task classes.
        let currentClassCount = Int(objc_getClassList(nil, 0))
        if currentClassCount > classCount {
            classCount = currentClassCount
            continue
        }

        for candidate in runtimeClasses.prefix(copiedCount).compactMap({ $0 }) {
            guard isURLSessionTaskSubclass(candidate) else {
                continue
            }
            appendIfOverridesSetState(candidate, selector: setStateSelector, to: &classes, seen: &seenClasses)
        }
        return classes
    }
}

private func isURLSessionTaskSubclass(_ candidate: AnyClass) -> Bool {
    var superclass = class_getSuperclass(candidate)
    while let current = superclass {
        if current === URLSessionTask.self {
            return true
        }
        superclass = class_getSuperclass(current)
    }
    return false
}

private func appendIfOverridesSetState(
    _ candidate: AnyClass,
    selector: Selector,
    to classes: inout [AnyClass],
    seen: inout Set<ObjectIdentifier>
) {
    guard let method = class_getInstanceMethod(candidate, selector) else {
        return
    }

    let superclassMethod = class_getInstanceMethod(class_getSuperclass(candidate), selector)
    let superclassImplementation = superclassMethod.map { method_getImplementation($0) }
    guard method_getImplementation(method) != superclassImplementation,
        seen.insert(ObjectIdentifier(candidate)).inserted
    else {
        return
    }

    classes.append(candidate)
}

/// Performs method swizzling on URLSession classes.
func swizzleUrlSession() {
    // Swizzle descendants before their superclasses. This ensures each class copies the
    // unswizzled inherited implementation into its local method entries before a superclass
    // implementation is exchanged.
    let classes = swizzledUrlSessionClasses().sorted {
        classDepth($0) > classDepth($1)
    }

    let setStateSelector = NSSelectorFromString("setState:")
    let resumeSelector = NSSelectorFromString("resume")

    for classToSwizzle in classes {
        swizzle(oneClass: classToSwizzle, original: setStateSelector, swizzled: #selector(URLSessionTask.splunkSwizzledSetState(state:)))

        // Each class now owns its swizzled method entry, so classes that share a resume IMP
        // still need an independent local hook.
        guard class_getInstanceMethod(classToSwizzle, resumeSelector) != nil else {
            continue
        }

        swizzle(oneClass: classToSwizzle, original: resumeSelector, swizzled: #selector(URLSessionTask.splunkSwizzledResume))
    }
}

private func classDepth(_ candidate: AnyClass) -> Int {
    var depth = 0
    var currentClass: AnyClass? = candidate
    while let current = currentClass {
        depth += 1
        currentClass = class_getSuperclass(current)
    }
    return depth
}
