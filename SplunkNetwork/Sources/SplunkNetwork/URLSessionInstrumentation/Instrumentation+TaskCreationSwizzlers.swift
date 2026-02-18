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

    var originalIMP: IMP?

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

        // Call the request-based method with injected headers.
        // The request-based swizzle will see trace context is already present and skip re-instrumentation.
        let task = session.dataTask(with: instrumentedRequest)
        objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
        return task
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    originalIMP = method_setImplementation(original, swizzledIMP)
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

    var originalIMP: IMP?

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

        // Wrap completion to end span
        let wrappedCompletion: CompletionHandler? = completion.map { originalCompletion in
            { data, response, error in
                endHttpSpanFromCompletion(span: span, response: response, error: error)
                originalCompletion(data, response, error)
            }
        }

        let task = castedIMP(session, selector, instrumentedRequest, wrappedCompletion)
        objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
        return task
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    originalIMP = method_setImplementation(original, swizzledIMP)
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

    var originalIMP: IMP?

    let block: @convention(block) (URLSession, URL, CompletionHandler?) -> URLSessionDataTask = { session, url, completion in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URL, CompletionHandler?) -> URLSessionDataTask).self
        )

        let request = URLRequest(url: url)
        guard shouldInstrumentRequest(request) else {
            return castedIMP(session, selector, url, completion)
        }

        // Create span and inject headers - need to use request-based method for instrumented request
        guard let span = startHttpSpan(request: request) else {
            return castedIMP(session, selector, url, completion)
        }

        let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)

        // Wrap completion to end span
        let wrappedCompletion: CompletionHandler? = completion.map { originalCompletion in
            { data, response, error in
                endHttpSpanFromCompletion(span: span, response: response, error: error)
                originalCompletion(data, response, error)
            }
        }

        // Use request-based method since we have an instrumented request
        let task = session.dataTask(with: instrumentedRequest, completionHandler: wrappedCompletion ?? { _, _, _ in })
        objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
        return task
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    originalIMP = method_setImplementation(original, swizzledIMP)
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

    var originalIMP: IMP?

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
    originalIMP = method_setImplementation(original, swizzledIMP)
}

func swizzleUploadTaskWithRequestFromFile() {
    let selector = #selector(URLSession.uploadTask(with:fromFile:))

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    var originalIMP: IMP?

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
    originalIMP = method_setImplementation(original, swizzledIMP)
}

// MARK: - Download Task Swizzling

func swizzleDownloadTaskWithRequest() {
    let selector = #selector(URLSession.downloadTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDownloadTask)
    swizzleDownloadTaskCreationMethod(selector: selector) { session, argument, originalIMP in
        guard let request = argument as? URLRequest else {
            return originalIMP(session, selector, argument)
        }
        return createInstrumentedDownloadTask(session: session, request: request, selector: selector, originalIMP: originalIMP)
    }
}

func swizzleDownloadTaskWithURL() {
    let selector = #selector(URLSession.downloadTask(with:) as (URLSession) -> (URL) -> URLSessionDownloadTask)

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    var originalIMP: IMP?

    let block: @convention(block) (URLSession, URL) -> URLSessionDownloadTask = { session, url in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URL) -> URLSessionDownloadTask).self
        )

        let request = URLRequest(url: url)
        guard shouldInstrumentRequest(request) else {
            return castedIMP(session, selector, url)
        }

        guard let span = startHttpSpan(request: request) else {
            return castedIMP(session, selector, url)
        }

        let instrumentedRequest = injectTraceContextIfEnabled(into: request, span: span)

        // Call the request-based method with injected headers.
        // The request-based swizzle will see trace context is already present and skip re-instrumentation.
        let task = session.downloadTask(with: instrumentedRequest)
        objc_setAssociatedObject(task, &associatedKeySpan, span, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(task, &associatedKeyInstrumented, true, .OBJC_ASSOCIATION_RETAIN)
        return task
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    originalIMP = method_setImplementation(original, swizzledIMP)
}
