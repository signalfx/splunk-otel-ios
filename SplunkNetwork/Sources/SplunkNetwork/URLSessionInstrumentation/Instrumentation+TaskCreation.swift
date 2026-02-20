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
import OpenTelemetryApi

// MARK: - Associated Object Keys

var associatedKeySpan: UInt8 = 0
var associatedKeyInstrumented: UInt8 = 1

// MARK: - Original IMP Storage

/// Stores original (un-swizzled) implementations of request-based methods.
/// These are captured before swizzling and used by URL-based swizzles to bypass
/// the swizzled request-based methods, preventing double instrumentation when
/// trace header injection is disabled.
enum OriginalIMPs {
    // Data task IMPs
    static var dataTaskWithRequest: IMP?
    static var dataTaskWithRequestAndCompletion: IMP?

    // Download task IMPs
    static var downloadTaskWithRequest: IMP?
}

/// Captures original request-based IMPs before any swizzling occurs.
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
    swizzleUploadTaskWithRequestFromFile()
    swizzleDownloadTaskWithRequest()
    swizzleDownloadTaskWithURL()
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
    originalIMP = method_setImplementation(original, swizzledIMP)
}

func createInstrumentedDataTask(
    session: URLSession,
    request: URLRequest,
    selector: Selector,
    originalIMP: (URLSession, Selector, Any) -> URLSessionDataTask
) -> URLSessionDataTask {
    guard shouldInstrumentRequest(request) else {
        return originalIMP(session, selector, request)
    }

    guard let span = startHttpSpan(request: request) else {
        return originalIMP(session, selector, request)
    }

    let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)
    let task = originalIMP(session, selector, instrumentedRequest)
    objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
    objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
    return task
}

func createInstrumentedDownloadTask(
    session: URLSession,
    request: URLRequest,
    selector: Selector,
    originalIMP: (URLSession, Selector, Any) -> URLSessionDownloadTask
) -> URLSessionDownloadTask {
    guard shouldInstrumentRequest(request) else {
        return originalIMP(session, selector, request)
    }

    guard let span = startHttpSpan(request: request) else {
        return originalIMP(session, selector, request)
    }

    let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)
    let task = originalIMP(session, selector, instrumentedRequest)
    objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
    objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
    return task
}

func shouldInstrumentRequest(_ request: URLRequest) -> Bool {
    // Don't double-instrument
    if TraceContextInjector.hasTraceContext(in: request) {
        return false
    }

    guard
        let url = request.url,
        url.scheme?.lowercased().starts(with: "http") == true
    else {
        return false
    }

    let manager = NetworkInstrumentationManager.shared

    // Check excluded endpoints
    if let excludedEndpoints = manager.getModule()?.excludedEndpoints,
        shouldExcludeURL(url, excludedEndpoints: excludedEndpoints)
    {
        return false
    }

    // Check ignoreURLs
    if let ignoreURLs = manager.getModule()?.getIgnoreURLs(),
        ignoreURLs.matches(url: url)
    {
        return false
    }

    return true
}

func injectTraceContextIfEnabled(into request: URLRequest, span: Span) -> URLRequest {
    // Check if trace header injection is enabled
    guard NetworkInstrumentationManager.shared.getModule()?.isTraceHeaderInjectionEnabled ?? true else {
        return request
    }

    return TraceContextInjector.injectTraceContext(into: request, spanContext: span.context)
}

func endHttpSpanFromCompletion(span: Span, response: URLResponse?, error: Error?) {
    if let httpResponse = response as? HTTPURLResponse {
        span.setAttribute(key: "http.response.status_code", value: httpResponse.statusCode)
    }

    if let error {
        span.setAttribute(key: "error", value: true)
        span.setAttribute(key: "error.message", value: error.localizedDescription)
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

/// Gets the span associated with a task during creation.
func getCreationSpan(for task: URLSessionTask) -> Span? {
    objc_getAssociatedObject(task, &associatedKeySpan) as? Span
}
