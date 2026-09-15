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

    // Capture original implementation BEFORE installing the swizzled block to avoid race condition
    let originalIMP = method_getImplementation(original)

    // Get the original request-based IMP to bypass the swizzled version
    let requestSelector = #selector(URLSession.downloadTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDownloadTask)
    guard let originalRequestIMP = OriginalIMPs.downloadTaskWithRequest else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Original downloadTask(with: URLRequest) IMP not captured"
        }
        return
    }

    let block: @convention(block) (URLSession, URL) -> URLSessionDownloadTask = { session, url in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URL) -> URLSessionDownloadTask).self
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
                    to: (@convention(c) (URLSession, Selector, URLRequest) -> URLSessionDownloadTask).self
                )
                return castedRequestIMP(session, requestSelector, instrumentedRequest)
            }
        )
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}

// MARK: - Download Task with Completion Handler Swizzling

func swizzleDownloadTaskWithRequestAndCompletion() {
    typealias DownloadHandler = (URL?, URLResponse?, Error?) -> Void
    let selector = #selector(
        URLSession.downloadTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping DownloadHandler) -> URLSessionDownloadTask
    )

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    let originalIMP = method_getImplementation(original)

    let block: @convention(block) (URLSession, URLRequest, DownloadHandler?) -> URLSessionDownloadTask = { session, request, completion in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URLRequest, DownloadHandler?) -> URLSessionDownloadTask).self
        )

        return createTaskWithInstrumentation(
            request: request,
            createOriginalTask: {
                castedIMP(session, selector, request, completion)
            },
            createInstrumentedTask: { instrumentedRequest, _, finalizationCoordinator in
                let wrappedCompletion = wrapDownloadCompletionHandler(
                    completion,
                    finalizationCoordinator: finalizationCoordinator
                )
                return castedIMP(session, selector, instrumentedRequest, wrappedCompletion)
            }
        )
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}

func swizzleDownloadTaskWithURLAndCompletion() {
    typealias DownloadHandler = (URL?, URLResponse?, Error?) -> Void
    let selector = #selector(
        URLSession.downloadTask(with:completionHandler:) as (URLSession) -> (URL, @escaping DownloadHandler) -> URLSessionDownloadTask
    )

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    let originalIMP = method_getImplementation(original)

    let requestSelector = #selector(
        URLSession.downloadTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping DownloadHandler) -> URLSessionDownloadTask
    )
    guard let originalRequestIMP = OriginalIMPs.downloadTaskWithRequestAndCompletion else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Original downloadTask(with: URLRequest, completionHandler:) IMP not captured"
        }
        return
    }

    let block: @convention(block) (URLSession, URL, DownloadHandler?) -> URLSessionDownloadTask = { session, url, completion in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, URL, DownloadHandler?) -> URLSessionDownloadTask).self
        )

        let request = URLRequest(url: url)
        return createTaskWithInstrumentation(
            request: request,
            createOriginalTask: {
                castedIMP(session, selector, url, completion)
            },
            createInstrumentedTask: { instrumentedRequest, _, finalizationCoordinator in
                let wrappedCompletion = wrapDownloadCompletionHandler(
                    completion,
                    finalizationCoordinator: finalizationCoordinator
                )
                let castedRequestIMP = unsafeBitCast(
                    originalRequestIMP,
                    to: (@convention(c) (URLSession, Selector, URLRequest, DownloadHandler?) -> URLSessionDownloadTask).self
                )
                return castedRequestIMP(session, requestSelector, instrumentedRequest, wrappedCompletion)
            }
        )
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}

// MARK: - Download Task with Resume Data Swizzling

func swizzleDownloadTaskWithResumeData() {
    let selector = #selector(URLSession.downloadTask(withResumeData:) as (URLSession) -> (Data) -> URLSessionDownloadTask)

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    let originalIMP = method_getImplementation(original)

    let block: @convention(block) (URLSession, Data) -> URLSessionDownloadTask = { session, resumeData in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, Data) -> URLSessionDownloadTask).self
        )

        let task = castedIMP(session, selector, resumeData)

        // Header injection is not possible for resumed downloads because the request
        // is embedded in the opaque resume data. We only create a span for observability.
        guard let request = task.currentRequest else {
            return task
        }

        return instrumentTaskAtCreationIfNeeded(task, request: request)
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}

func swizzleDownloadTaskWithResumeDataAndCompletion() {
    typealias DownloadHandler = (URL?, URLResponse?, Error?) -> Void
    let selector = #selector(
        URLSession.downloadTask(withResumeData:completionHandler:) as (URLSession) -> (Data, @escaping DownloadHandler) -> URLSessionDownloadTask
    )

    guard let original = class_getInstanceMethod(URLSession.self, selector) else {
        NetworkInstrumentationManager.shared.logger.log(level: .fault) {
            "Failed to swizzle \(NSStringFromSelector(selector))"
        }
        return
    }

    let originalIMP = method_getImplementation(original)

    let block: @convention(block) (URLSession, Data, DownloadHandler?) -> URLSessionDownloadTask = { session, resumeData, completion in
        let castedIMP = unsafeBitCast(
            originalIMP,
            to: (@convention(c) (URLSession, Selector, Data, DownloadHandler?) -> URLSessionDownloadTask).self
        )

        // Create the task first since the request is embedded in resume data
        let task = castedIMP(session, selector, resumeData, completion)

        guard let request = task.currentRequest else {
            return task
        }

        return instrumentTaskAtCreationIfNeeded(task, request: request)
    }

    let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
    method_setImplementation(original, swizzledIMP)
}
