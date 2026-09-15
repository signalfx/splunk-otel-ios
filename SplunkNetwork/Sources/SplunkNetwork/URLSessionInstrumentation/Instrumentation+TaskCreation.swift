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
@_spi(SplunkInternal) import SplunkCommon

// MARK: - Associated Object Keys

var associatedKeySpan: UInt8 = 0
var associatedKeyInstrumented: UInt8 = 1
var associatedKeySkipped: UInt8 = 2
var associatedKeyFinalizationCoordinator: UInt8 = 3

// MARK: - Original IMP Storage

/// Stores original (un-swizzled) implementations of request-based methods.
///
/// These are captured before swizzling and used by URL-based swizzles to bypass
/// the swizzled request-based methods, preventing double instrumentation when
/// trace header injection is disabled.
enum OriginalIMPs {
    static var dataTaskWithRequest: IMP?
    static var dataTaskWithRequestAndCompletion: IMP?
    static var downloadTaskWithRequest: IMP?
    static var downloadTaskWithRequestAndCompletion: IMP?
}

/// Captures original request-based IMPs before any swizzling occurs.
///
/// Must be called first in swizzleURLSessionTaskCreation().
private func captureOriginalIMPs() {
    // Capture dataTask(with: URLRequest)
    let dataTaskRequestSelector = #selector(URLSession.dataTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDataTask)
    if let method = class_getInstanceMethod(URLSession.self, dataTaskRequestSelector) {
        OriginalIMPs.dataTaskWithRequest = method_getImplementation(method)
    }

    // Capture dataTask(with: URLRequest, completionHandler:)
    typealias DataCompletionHandler = (Data?, URLResponse?, Error?) -> Void
    let dataTaskRequestCompletionSelector = #selector(
        URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping DataCompletionHandler) -> URLSessionDataTask
    )
    if let method = class_getInstanceMethod(URLSession.self, dataTaskRequestCompletionSelector) {
        OriginalIMPs.dataTaskWithRequestAndCompletion = method_getImplementation(method)
    }

    // Capture downloadTask(with: URLRequest)
    let downloadTaskRequestSelector = #selector(URLSession.downloadTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDownloadTask)
    if let method = class_getInstanceMethod(URLSession.self, downloadTaskRequestSelector) {
        OriginalIMPs.downloadTaskWithRequest = method_getImplementation(method)
    }

    // Capture downloadTask(with: URLRequest, completionHandler:)
    typealias DownloadCompletionHandler = (URL?, URLResponse?, Error?) -> Void
    let downloadTaskRequestCompletionSelector = #selector(
        URLSession.downloadTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping DownloadCompletionHandler) -> URLSessionDownloadTask
    )
    if let method = class_getInstanceMethod(URLSession.self, downloadTaskRequestCompletionSelector) {
        OriginalIMPs.downloadTaskWithRequestAndCompletion = method_getImplementation(method)
    }
}

// MARK: - Task Creation Swizzling

/// Swizzles URLSession task creation methods to enable trace context injection.
///
/// This must be called during instrumentation initialization to intercept task creation
/// and inject W3C trace context headers into outgoing requests.
func swizzleURLSessionTaskCreation() {
    // Capture original IMPs BEFORE any swizzling to allow URL-based swizzles
    // to bypass request-based swizzles (prevents double instrumentation)
    captureOriginalIMPs()

    swizzleDataTaskWithRequest()
    swizzleDataTaskWithURL()
    swizzleDataTaskWithRequestAndCompletion()
    swizzleDataTaskWithURLAndCompletion()
    swizzleUploadTaskWithRequestFromData()
    swizzleUploadTaskWithRequestFromDataAndCompletion()
    swizzleUploadTaskWithRequestFromFile()
    swizzleUploadTaskWithRequestFromFileAndCompletion()
    swizzleDownloadTaskWithRequest()
    swizzleDownloadTaskWithURL()
    swizzleDownloadTaskWithRequestAndCompletion()
    swizzleDownloadTaskWithURLAndCompletion()
    swizzleDownloadTaskWithResumeData()
    swizzleDownloadTaskWithResumeDataAndCompletion()
    swizzleUploadTaskWithStreamedRequest()
}

// MARK: - Helper Functions

enum RequestInstrumentationDecision {
    case instrumentAtCreation
    case deferToResume
    case skipInstrumentation
}

func swizzleTaskCreationMethod(
    selector: Selector,
    handler: @escaping (URLSession, Any, @escaping (URLSession, Selector, Any) -> URLSessionDataTask) -> URLSessionDataTask
) {
    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    // Capture original implementation BEFORE installing the swizzled block to avoid race condition
    let originalIMP = method_getImplementation(original)

    let block: @convention(block) (URLSession, Any) -> URLSessionDataTask = { session, argument in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, Any) -> URLSessionDataTask).self
        )
        return handler(session, argument, castedIMP)
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}

func swizzleDownloadTaskCreationMethod(
    selector: Selector,
    handler: @escaping (URLSession, Any, @escaping (URLSession, Selector, Any) -> URLSessionDownloadTask) -> URLSessionDownloadTask
) {
    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    // Capture original implementation BEFORE installing the swizzled block to avoid race condition
    let originalIMP = method_getImplementation(original)

    let block: @convention(block) (URLSession, Any) -> URLSessionDownloadTask = { session, argument in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, Any) -> URLSessionDownloadTask).self
        )
        return handler(session, argument, castedIMP)
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}

/// Creates a data task with instrumentation: starts a span, injects trace headers, and
/// associates the span with the task.
///
/// The span starts at creation time because `traceparent` header injection requires a
/// valid `SpanContext` before the request is sent. Actual network activity begins when
/// the task is resumed; `splunkSwizzledResume` records an `http.request.started` event
/// so downstream systems can compute accurate network duration.
func createInstrumentedDataTask(
    session: URLSession,
    request: URLRequest,
    selector: Selector,
    originalIMP: (URLSession, Selector, Any) -> URLSessionDataTask
) -> URLSessionDataTask {
    createTaskWithInstrumentation(
        request: request,
        createOriginalTask: {
            originalIMP(session, selector, request)
        },
        createInstrumentedTask: { instrumentedRequest, _ in
            originalIMP(session, selector, instrumentedRequest)
        }
    )
}

/// Creates a download task with instrumentation: starts a span, injects trace headers, and
/// associates the span with the task.
///
/// See ``createInstrumentedDataTask`` for details on the creation-vs-resume timing model.
func createInstrumentedDownloadTask(
    session: URLSession,
    request: URLRequest,
    selector: Selector,
    originalIMP: (URLSession, Selector, Any) -> URLSessionDownloadTask
) -> URLSessionDownloadTask {
    createTaskWithInstrumentation(
        request: request,
        createOriginalTask: {
            originalIMP(session, selector, request)
        },
        createInstrumentedTask: { instrumentedRequest, _ in
            originalIMP(session, selector, instrumentedRequest)
        }
    )
}

func instrumentationDecision(for request: URLRequest) -> RequestInstrumentationDecision {
    if InternalNetworkRequestMarker.isMarked(request) {
        return .skipInstrumentation
    }

    if TraceContextInjector.hasTraceContext(in: request) {
        return .deferToResume
    }

    return .instrumentAtCreation
}

func createTaskWithInstrumentation<T: URLSessionTask>(
    request: URLRequest,
    createOriginalTask: () -> T,
    createInstrumentedTask: (_ instrumentedRequest: URLRequest, _ span: Span) -> T
) -> T {
    createTaskWithInstrumentation(
        request: request,
        createOriginalTask: createOriginalTask,
        createInstrumentedTask: { instrumentedRequest, span, _ in
            createInstrumentedTask(instrumentedRequest, span)
        }
    )
}

func createTaskWithInstrumentation<T: URLSessionTask>(
    request: URLRequest,
    createOriginalTask: () -> T,
    createInstrumentedTask: (
        _ instrumentedRequest: URLRequest,
        _ span: Span,
        _ finalizationCoordinator: NetworkSpanFinalizationCoordinator
    ) -> T
) -> T {
    switch instrumentationDecision(for: request) {
    case .skipInstrumentation:
        return markSkippedForInstrumentation(createOriginalTask())

    case .deferToResume:
        return createOriginalTask()

    case .instrumentAtCreation:
        guard let span = startHttpSpan(request: request) else {
            return markSkippedForInstrumentation(createOriginalTask())
        }

        let finalizationCoordinator = NetworkSpanFinalizationCoordinator(span: span)
        let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)
        return markInstrumentedAtCreation(
            createInstrumentedTask(instrumentedRequest, span, finalizationCoordinator),
            span: span,
            finalizationCoordinator: finalizationCoordinator
        )
    }
}

func instrumentTaskAtCreationIfNeeded<T: URLSessionTask>(
    _ task: T,
    request: URLRequest
) -> T {
    switch instrumentationDecision(for: request) {
    case .skipInstrumentation:
        return markSkippedForInstrumentation(task)

    case .deferToResume:
        return task

    case .instrumentAtCreation:
        guard let span = startHttpSpan(request: request) else {
            return markSkippedForInstrumentation(task)
        }

        return markInstrumentedAtCreation(task, span: span)
    }
}

func injectTraceContextIfEnabled(into request: URLRequest, span: Span) -> URLRequest {
    // Check if trace header injection is enabled
    guard NetworkInstrumentationManager.shared.getModule()?.isTraceHeaderInjectionEnabled ?? false else {
        return request
    }

    return TraceContextInjector.injectTraceContext(into: request, spanContext: span.context)
}

/// Wraps an optional completion handler to finalize the span when the request completes.
///
/// The completion handler and task-state callback share one coordinator. Whichever observes
/// completion first performs task-aware enrichment and ends the span exactly once.
func wrapCompletionHandler(
    _ completion: ((Data?, URLResponse?, Error?) -> Void)?,
    finalizationCoordinator: NetworkSpanFinalizationCoordinator
) -> (Data?, URLResponse?, Error?) -> Void {
    guard let originalCompletion = completion else {
        return { _, response, error in
            finalizationCoordinator.finalize(response: response, error: error)
        }
    }

    return { data, response, error in
        finalizationCoordinator.finalize(response: response, error: error)
        originalCompletion(data, response, error)
    }
}

/// Wraps an optional download completion handler to end the span when the download completes.
///
/// Download tasks use a different completion signature `(URL?, URLResponse?, Error?)` where
/// the first parameter is the temporary file location. The span-ending semantics are identical
/// to ``wrapCompletionHandler``.
func wrapDownloadCompletionHandler(
    _ completion: ((URL?, URLResponse?, Error?) -> Void)?,
    finalizationCoordinator: NetworkSpanFinalizationCoordinator
) -> (URL?, URLResponse?, Error?) -> Void {
    guard let originalCompletion = completion else {
        return { _, response, error in
            finalizationCoordinator.finalize(response: response, error: error)
        }
    }

    return { url, response, error in
        finalizationCoordinator.finalize(response: response, error: error)
        originalCompletion(url, response, error)
    }
}

// MARK: - Check if Task was Instrumented at Creation

/// Checks if a URLSessionTask was already instrumented during task creation.
///
/// This is used by the resume swizzling to avoid double instrumentation.
func wasInstrumentedAtCreation(_ task: URLSessionTask) -> Bool {
    objc_getAssociatedObject(task, &associatedKeyInstrumented) as? Bool ?? false
}

/// Checks if a URLSessionTask was intentionally skipped during task creation.
func wasSkippedForInstrumentation(_ task: URLSessionTask) -> Bool {
    objc_getAssociatedObject(task, &associatedKeySkipped) as? Bool ?? false
}

/// Marks a URLSessionTask as intentionally skipped during task creation.
func markSkippedForInstrumentation<T: URLSessionTask>(_ task: T) -> T {
    objc_setAssociatedObject(task, &associatedKeySkipped, true, .OBJC_ASSOCIATION_RETAIN)
    return task
}

func markInstrumentedAtCreation<T: URLSessionTask>(
    _ task: T,
    span: Span,
    finalizationCoordinator: NetworkSpanFinalizationCoordinator? = nil
) -> T {
    let coordinator = finalizationCoordinator ?? NetworkSpanFinalizationCoordinator(span: span)
    coordinator.attach(to: task)
    objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
    objc_setAssociatedObject(task, &associatedKeyFinalizationCoordinator, coordinator, .OBJC_ASSOCIATION_RETAIN)
    objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
    return task
}

/// Gets the span associated with a task during creation.
func getCreationSpan(for task: URLSessionTask) -> Span? {
    objc_getAssociatedObject(task, &associatedKeySpan) as? Span
}

/// Gets the exactly-once span finalizer associated with an instrumented task.
func getSpanFinalizationCoordinator(for task: URLSessionTask) -> NetworkSpanFinalizationCoordinator? {
    objc_getAssociatedObject(task, &associatedKeyFinalizationCoordinator) as? NetworkSpanFinalizationCoordinator
}

/// Associates an exactly-once span finalizer with a task instrumented during `resume()`.
func setSpanFinalizationCoordinator(
    _ coordinator: NetworkSpanFinalizationCoordinator,
    for task: URLSessionTask
) {
    coordinator.attach(to: task)
    objc_setAssociatedObject(task, &associatedKeyFinalizationCoordinator, coordinator, .OBJC_ASSOCIATION_RETAIN)
}
