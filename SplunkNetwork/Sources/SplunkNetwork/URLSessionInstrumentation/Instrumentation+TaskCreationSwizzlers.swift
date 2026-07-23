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
        return createTaskWithInstrumentation(
            request: request,
            createOriginalTask: {
                castedIMP(session, selector, url)
            },
            createInstrumentedTask: { instrumentedRequest, _ in
                // Call the ORIGINAL (un-swizzled) request-based method directly.
                // This bypasses the request-based swizzle, preventing double instrumentation
                // when trace header injection is disabled.
                let castedRequestIMP = unsafeBitCast(
                    originalRequestIMP,
                    to: (@convention(c) (URLSession, Selector, URLRequest) -> URLSessionDataTask).self
                )
                return castedRequestIMP(session, requestSelector, instrumentedRequest)
            }
        )
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

        return createTaskWithInstrumentation(
            request: request,
            createOriginalTask: {
                castedIMP(session, selector, request, completion)
            },
            createInstrumentedTask: { instrumentedRequest, span in
                let wrappedCompletion = wrapCompletionHandler(completion, span: span)
                return castedIMP(session, selector, instrumentedRequest, wrappedCompletion)
            }
        )
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
        return createTaskWithInstrumentation(
            request: request,
            createOriginalTask: {
                castedIMP(session, selector, url, completion)
            },
            createInstrumentedTask: { instrumentedRequest, span in
                let wrappedCompletion = wrapCompletionHandler(completion, span: span)

                // Call the ORIGINAL (un-swizzled) request-based method directly.
                // This bypasses the request-based swizzle, preventing double instrumentation
                // when trace header injection is disabled.
                let castedRequestIMP = unsafeBitCast(
                    originalRequestIMP,
                    to: (@convention(c) (URLSession, Selector, URLRequest, CompletionHandler?) -> URLSessionDataTask).self
                )
                return castedRequestIMP(session, requestSelector, instrumentedRequest, wrappedCompletion)
            }
        )
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

        return createTaskWithInstrumentation(
            request: request,
            createOriginalTask: {
                castedIMP(session, selector, request, data)
            },
            createInstrumentedTask: { instrumentedRequest, _ in
                castedIMP(session, selector, instrumentedRequest, data)
            }
        )
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

        return createTaskWithInstrumentation(
            request: request,
            createOriginalTask: {
                castedIMP(session, selector, request, fileURL)
            },
            createInstrumentedTask: { instrumentedRequest, _ in
                castedIMP(session, selector, instrumentedRequest, fileURL)
            }
        )
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

        return createTaskWithInstrumentation(
            request: request,
            createOriginalTask: {
                castedIMP(session, selector, request, data, completion)
            },
            createInstrumentedTask: { instrumentedRequest, span in
                let wrappedCompletion = wrapCompletionHandler(completion, span: span)
                return castedIMP(session, selector, instrumentedRequest, data, wrappedCompletion)
            }
        )
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

        return createTaskWithInstrumentation(
            request: request,
            createOriginalTask: {
                castedIMP(session, selector, request, fileURL, completion)
            },
            createInstrumentedTask: { instrumentedRequest, span in
                let wrappedCompletion = wrapCompletionHandler(completion, span: span)
                return castedIMP(session, selector, instrumentedRequest, fileURL, wrappedCompletion)
            }
        )
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

        return createTaskWithInstrumentation(
            request: request,
            createOriginalTask: {
                castedIMP(session, selector, request)
            },
            createInstrumentedTask: { instrumentedRequest, _ in
                castedIMP(session, selector, instrumentedRequest)
            }
        )
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}
