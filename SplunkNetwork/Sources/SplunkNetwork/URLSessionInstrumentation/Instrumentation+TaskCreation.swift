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
    guard shouldInstrumentRequest(request) else {
        return markSkippedForInstrumentation(originalIMP(session, selector, request))
    }

    guard let span = startHttpSpan(request: request) else {
        return markSkippedForInstrumentation(originalIMP(session, selector, request))
    }

    let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)
    let task = originalIMP(session, selector, instrumentedRequest)
    objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
    objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
    return task
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
    guard shouldInstrumentRequest(request) else {
        return markSkippedForInstrumentation(originalIMP(session, selector, request))
    }

    guard let span = startHttpSpan(request: request) else {
        return markSkippedForInstrumentation(originalIMP(session, selector, request))
    }

    let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)
    let task = originalIMP(session, selector, instrumentedRequest)
    objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
    objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
    return task
}

func shouldInstrumentRequest(_ request: URLRequest) -> Bool {
    // Prevent instrumentation of SDK-owned requests and double-instrumentation of
    // requests that already carry trace context.
    // All other filtering (URL scheme, excluded endpoints, ignoreURLs) is handled
    // by startHttpSpan, which is always called immediately after this check.
    !InternalNetworkRequestMarker.isMarked(request)
        && !TraceContextInjector.hasTraceContext(in: request)
}

func injectTraceContextIfEnabled(into request: URLRequest, span: Span) -> URLRequest {
    // Check if trace header injection is enabled
    guard NetworkInstrumentationManager.shared.getModule()?.isTraceHeaderInjectionEnabled ?? false else {
        return request
    }

    return TraceContextInjector.injectTraceContext(into: request, spanContext: span.context)
}

/// Wraps an optional completion handler to end the span when the request completes.
///
/// For tasks instrumented at creation time, two span-ending paths exist:
/// 1. `splunkSwizzledSetState` (in `Instrumentation+Swizzling.swift`) calls `endHttpSpan`,
///    which sets rich attributes (status code, server-timing link, response body size,
///    peer address, protocol version, error details, request body size).
/// 2. This wrapped completion handler calls `endHttpSpanFromCompletion`, which sets
///    status code, configured captured response headers, and error attributes.
///
/// On Apple platforms, `setState:` fires before the completion handler, so `endHttpSpan`
/// runs first and the span receives the full attribute set. The subsequent `end()` call
/// from the completion handler is a no-op (OpenTelemetry ignores writes to ended spans).
func wrapCompletionHandler(
    _ completion: ((Data?, URLResponse?, Error?) -> Void)?,
    span: Span
) -> (Data?, URLResponse?, Error?) -> Void {
    guard let originalCompletion = completion else {
        return { _, response, error in
            endHttpSpanFromCompletion(span: span, response: response, error: error)
        }
    }

    return { data, response, error in
        endHttpSpanFromCompletion(span: span, response: response, error: error)
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
    span: Span
) -> (URL?, URLResponse?, Error?) -> Void {
    guard let originalCompletion = completion else {
        return { _, response, error in
            endHttpSpanFromCompletion(span: span, response: response, error: error)
        }
    }

    return { url, response, error in
        endHttpSpanFromCompletion(span: span, response: response, error: error)
        originalCompletion(url, response, error)
    }
}

/// Ends a span from a completion handler with fallback attributes.
///
/// This is a safety net for tasks whose span was not already ended by `splunkSwizzledSetState`.
/// See ``wrapCompletionHandler`` for details on the dual-path span lifecycle.
func endHttpSpanFromCompletion(span: Span, response: URLResponse?, error: Error?) {
    if let httpResponse = response as? HTTPURLResponse {
        span.clearAndSetAttribute(key: SemanticConventions.Http.responseStatusCode, value: httpResponse.statusCode)
        addCapturedResponseHeaders(from: httpResponse, to: span)
    }

    if let error {
        span.clearAndSetAttribute(key: NetworkSpanAttributeKeys.error, value: true)
        span.clearAndSetAttribute(key: SemanticConventions.Error.message, value: error.localizedDescription)
    }

    span.end()
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

/// Gets the span associated with a task during creation.
func getCreationSpan(for task: URLSessionTask) -> Span? {
    objc_getAssociatedObject(task, &associatedKeySpan) as? Span
}
