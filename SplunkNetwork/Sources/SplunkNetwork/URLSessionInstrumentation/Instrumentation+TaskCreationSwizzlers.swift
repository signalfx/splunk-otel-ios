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

// MARK: - Data Task Swizzling

func swizzleDataTaskWithRequest() {
    let selector = #selector(URLSession.dataTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDataTask)
    swizzleTaskCreationMethod(selector: selector) { session, argument, originalIMP in
        guard let request = argument as? URLRequest else {
            return originalIMP(session, selector, argument)
        }

        return createInstrumentedDataTask(session: session, request: request, selector: selector, originalIMP: originalIMP)
    }
}

func swizzleDataTaskWithURL() {
    let selector = #selector(URLSession.dataTask(with:) as (URLSession) -> (URL) -> URLSessionDataTask)

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    // Capture original implementation BEFORE installing the swizzled block to avoid race condition
    let originalIMP = method_getImplementation(original)

    // Get the original request-based IMP to bypass the swizzled version
    let requestSelector = #selector(URLSession.dataTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDataTask)
    guard let originalRequestIMP = OriginalIMPs.dataTaskWithRequest else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Original dataTask(with: URLRequest) IMP not captured"
        }
        return
    }

    let block: @convention(block) (URLSession, URL) -> URLSessionDataTask = { session, url in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URL) -> URLSessionDataTask).self
        )

        let request = URLRequest(url: url)
        guard shouldInstrumentRequest(request) else {
            return castedIMP(session, selector, url)
        }

        guard let span = startHttpSpan(request: request) else {
            return castedIMP(session, selector, url)
        }

        let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)

        // Call the ORIGINAL (un-swizzled) request-based method directly.
        // This bypasses the request-based swizzle, preventing double instrumentation
        // when trace header injection is disabled.
        let castedRequestIMP = unsafeBitCast(
            originalRequestIMP,
            to: (@convention(c) (URLSession, Selector, URLRequest) -> URLSessionDataTask).self
        )
        let task = castedRequestIMP(session, requestSelector, instrumentedRequest)
        objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
        return task
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}

func swizzleDataTaskWithRequestAndCompletion() {
    typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    let selector = #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping CompletionHandler) -> URLSessionDataTask)

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    // Capture original implementation BEFORE installing the swizzled block to avoid race condition
    let originalIMP = method_getImplementation(original)

    let block: @convention(block) (URLSession, URLRequest, CompletionHandler?) -> URLSessionDataTask = { session, request, completion in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URLRequest, CompletionHandler?) -> URLSessionDataTask).self
        )

        guard shouldInstrumentRequest(request) else {
            return castedIMP(session, selector, request, completion)
        }

        // Create span and inject headers
        guard let span = startHttpSpan(request: request) else {
            return castedIMP(session, selector, request, completion)
        }

        let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)
        let wrappedCompletion = wrapCompletionHandler(completion, span: span)

        let task = castedIMP(session, selector, instrumentedRequest, wrappedCompletion)
        objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
        return task
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}

func swizzleDataTaskWithURLAndCompletion() {
    typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    let selector = #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URL, @escaping CompletionHandler) -> URLSessionDataTask)

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    // Capture original implementation BEFORE installing the swizzled block to avoid race condition
    let originalIMP = method_getImplementation(original)

    // Get the original request-based IMP to bypass the swizzled version
    let requestSelector = #selector(
        URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping CompletionHandler) -> URLSessionDataTask
    )
    guard let originalRequestIMP = OriginalIMPs.dataTaskWithRequestAndCompletion else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Original dataTask(with: URLRequest, completionHandler:) IMP not captured"
        }
        return
    }

    let block: @convention(block) (URLSession, URL, CompletionHandler?) -> URLSessionDataTask = { session, url, completion in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URL, CompletionHandler?) -> URLSessionDataTask).self
        )

        let request = URLRequest(url: url)
        guard shouldInstrumentRequest(request) else {
            return castedIMP(session, selector, url, completion)
        }

        // Create span and inject headers
        guard let span = startHttpSpan(request: request) else {
            return castedIMP(session, selector, url, completion)
        }

        let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)
        let wrappedCompletion = wrapCompletionHandler(completion, span: span)

        // Call the ORIGINAL (un-swizzled) request-based method directly.
        // This bypasses the request-based swizzle, preventing double instrumentation
        // when trace header injection is disabled.
        let castedRequestIMP = unsafeBitCast(
            originalRequestIMP,
            to: (@convention(c) (URLSession, Selector, URLRequest, CompletionHandler?) -> URLSessionDataTask).self
        )
        let task = castedRequestIMP(session, requestSelector, instrumentedRequest, wrappedCompletion)
        objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
        return task
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}

// MARK: - Upload Task Swizzling

func swizzleUploadTaskWithRequestFromData() {
    let selector = #selector(URLSession.uploadTask(with:from:))

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    // Capture original implementation BEFORE installing the swizzled block to avoid race condition
    let originalIMP = method_getImplementation(original)

    let block: @convention(block) (URLSession, URLRequest, Data?) -> URLSessionUploadTask = { session, request, data in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URLRequest, Data?) -> URLSessionUploadTask).self
        )

        guard shouldInstrumentRequest(request) else {
            return castedIMP(session, selector, request, data)
        }

        guard let span = startHttpSpan(request: request) else {
            return castedIMP(session, selector, request, data)
        }

        let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)
        let task = castedIMP(session, selector, instrumentedRequest, data)
        objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
        return task
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}

func swizzleUploadTaskWithRequestFromFile() {
    let selector = #selector(URLSession.uploadTask(with:fromFile:))

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    // Capture original implementation BEFORE installing the swizzled block to avoid race condition
    let originalIMP = method_getImplementation(original)

    let block: @convention(block) (URLSession, URLRequest, URL) -> URLSessionUploadTask = { session, request, fileURL in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URLRequest, URL) -> URLSessionUploadTask).self
        )

        guard shouldInstrumentRequest(request) else {
            return castedIMP(session, selector, request, fileURL)
        }

        guard let span = startHttpSpan(request: request) else {
            return castedIMP(session, selector, request, fileURL)
        }

        let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)
        let task = castedIMP(session, selector, instrumentedRequest, fileURL)
        objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
        return task
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}

func swizzleUploadTaskWithRequestFromDataAndCompletion() {
    typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    let selector = #selector(
        URLSession.uploadTask(with:from:completionHandler:) as (URLSession) -> (URLRequest, Data?, @escaping CompletionHandler) -> URLSessionUploadTask
    )

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    // Capture original implementation BEFORE installing the swizzled block to avoid race condition
    let originalIMP = method_getImplementation(original)

    let block: @convention(block) (URLSession, URLRequest, Data?, CompletionHandler?) -> URLSessionUploadTask = { session, request, data, completion in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URLRequest, Data?, CompletionHandler?) -> URLSessionUploadTask).self
        )

        guard shouldInstrumentRequest(request) else {
            return castedIMP(session, selector, request, data, completion)
        }

        guard let span = startHttpSpan(request: request) else {
            return castedIMP(session, selector, request, data, completion)
        }

        let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)
        let wrappedCompletion = wrapCompletionHandler(completion, span: span)

        let task = castedIMP(session, selector, instrumentedRequest, data, wrappedCompletion)
        objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
        return task
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}

func swizzleUploadTaskWithRequestFromFileAndCompletion() {
    typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    let selector = #selector(
        URLSession.uploadTask(with:fromFile:completionHandler:) as (URLSession) -> (URLRequest, URL, @escaping CompletionHandler) -> URLSessionUploadTask
    )

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    // Capture original implementation BEFORE installing the swizzled block to avoid race condition
    let originalIMP = method_getImplementation(original)

    let block: @convention(block) (URLSession, URLRequest, URL, CompletionHandler?) -> URLSessionUploadTask = { session, request, fileURL, completion in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URLRequest, URL, CompletionHandler?) -> URLSessionUploadTask).self
        )

        guard shouldInstrumentRequest(request) else {
            return castedIMP(session, selector, request, fileURL, completion)
        }

        guard let span = startHttpSpan(request: request) else {
            return castedIMP(session, selector, request, fileURL, completion)
        }

        let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)
        let wrappedCompletion = wrapCompletionHandler(completion, span: span)

        let task = castedIMP(session, selector, instrumentedRequest, fileURL, wrappedCompletion)
        objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
        return task
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}

// MARK: - Streamed Upload Task Swizzling

func swizzleUploadTaskWithStreamedRequest() {
    let selector = #selector(URLSession.uploadTask(withStreamedRequest:))

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    let originalIMP = method_getImplementation(original)

    let block: @convention(block) (URLSession, URLRequest) -> URLSessionUploadTask = { session, request in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URLRequest) -> URLSessionUploadTask).self
        )

        guard shouldInstrumentRequest(request) else {
            return castedIMP(session, selector, request)
        }

        guard let span = startHttpSpan(request: request) else {
            return castedIMP(session, selector, request)
        }

        let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)
        let task = castedIMP(session, selector, instrumentedRequest)
        objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
        return task
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}
